package
{
	import flash.data.*;
	import flash.errors.SQLError;
	import flash.events.SQLErrorEvent;
	import flash.events.SQLEvent;
	import flash.filesystem.File;
	import flash.net.Responder;
	
	public class DBInstance
	{
		private var _dbConn:SQLConnection;
		private var _ready:Boolean;
		private var _isAsync:Boolean;
		
		public function DBInstance(dbFilePath:String, isAsync:Boolean)
		{
			if (dbFilePath == null)
				throw new ArgumentError("A database file path must be specified.");
			
			// create the database if it doesn't exist.
			_ready = false;
			_dbConn = openSyncConnection(dbFilePath);
			_isAsync = false;
			_ready = true;
			createTableIfNotExist(_dbConn);
			
			// open an async connection if needed
			if (isAsync)
			{
				// close the current synchronous one
				_dbConn.close();
				_ready = false;
				
				var callback:Function = function (event:SQLEvent):void 
				{
					_ready = true;
				};
				
				_dbConn = openAsyncConnection(dbFilePath, callback);
				_isAsync = true;
			}
		}
		
		public function get connection():SQLConnection
		{
			return _dbConn;
		}
		
		public function get ready():Boolean
		{
			return _ready;
		}
		
		public function get isAsync():Boolean
		{
			return _isAsync;
		}
		
		private function openSyncConnection(dbFilePath:String):SQLConnection
		{
			var conn:SQLConnection = new SQLConnection();
			conn.open(new File(dbFilePath), SQLMode.CREATE);
			
			return conn;
		}
		
		private function openAsyncConnection(dbFilePath:String, callback:Function):SQLConnection
		{
			var conn:SQLConnection = new SQLConnection();
			if (callback != null) conn.addEventListener(SQLEvent.OPEN, callback);
			conn.openAsync(new File(dbFilePath), SQLMode.CREATE);
			
			return conn;
		}
		
		// expects db connection to be synchronous
		private function createTableIfNotExist(dbConn:SQLConnection):void
		{
			var sql:SQLStatement = new SQLStatement();
			sql.sqlConnection = dbConn;
			sql.text = "CREATE TABLE IF NOT EXISTS StressTest (" +
				"id INTEGER PRIMARY KEY, " +
				"title TEXT, " +
				"number INTEGER, " +
				"date DATE" +
				")";
			
			sql.execute();
		}
		
		public function save(dbRecord:DBRecord, callback:Function):void
		{
			var sql:SQLStatement = new SQLStatement();
			sql.sqlConnection = _dbConn;
			
			sql.text = "INSERT OR REPLACE " +
				"INTO StressTest (" +
				"title, " +
				"number, " +
				"date" +
				") " +
				"VALUES (" +
				"@title, " +
				"@number, " +
				"@date" +
				")";
			
			sql.parameters["@title"] = dbRecord.title;
			sql.parameters["@number"] = dbRecord.number;
			sql.parameters["@date"] = dbRecord.date;
			
			// callbacks
			var resultCallback:Function = function (event:SQLEvent):void
			{
				var result:SQLResult = sql.getResult();
				
				if (result.rowsAffected == 0)
				{
					// something went wrong - row was not updated
					if (callback != null)
						callback(new DBEvent(DBEvent.ERROR));
					return;
				}
				
				// save id
				dbRecord.id = result.lastInsertRowID;
				
				// let caller know
				if (callback != null)
					callback(new DBEvent(DBEvent.SUCCESSFUL));
			};
			var errorCallback:Function = function (event:SQLErrorEvent):void
			{
				trace("errorID: " + event.errorID);
				
				// let caller know of error
				if (callback != null)
					callback(new DBEvent(DBEvent.ERROR, event.error.details));
			};
			
			if (isAsync)
			{
				sql.addEventListener(SQLErrorEvent.ERROR, errorCallback);
				sql.addEventListener(SQLEvent.RESULT, resultCallback);
				sql.execute();
			}
			else
			{
				// synchronous
				try
				{
					sql.execute();
					resultCallback(new SQLEvent(SQLEvent.RESULT));
				}
				catch (error:SQLError)
				{
					errorCallback(new SQLErrorEvent(SQLErrorEvent.ERROR, false, false, error));
				}
			}
		}
		
		public function getByTitle(title:String, callback:Function):void
		{
			var sql:SQLStatement = new SQLStatement();
			sql.sqlConnection = _dbConn;
			
			sql.text = "SELECT * " +
				"FROM StressTest " +
				"WHERE title = @title";
			
			sql.parameters["@title"] = title;
			
			// callbacks
			var resultCallback:Function = function (event:SQLEvent):void
			{
				var result:SQLResult = sql.getResult();
				
				if (result.data.length == 0)
				{
					// something went wrong - row was not updated
					if (callback != null)
						callback(new DBEvent(DBEvent.ERROR));
					return;
				}
				
				var record:DBRecord = new DBRecord();
				record.id = result.data[0]["id"];
				record.title = result.data[0]["title"];
				record.number = result.data[0]["number"];
				record.date = result.data[0]["date"];
				
				// let caller know
				if (callback != null)
					callback(new DBEvent(DBEvent.SUCCESSFUL, "", record));
			};
			var errorCallback:Function = function (event:SQLErrorEvent):void
			{
				trace("errorID: " + event.errorID);
				
				// let caller know of error
				if (callback != null)
					callback(new DBEvent(DBEvent.ERROR, event.error.details));
			};
			
			if (isAsync)
			{
				sql.addEventListener(SQLErrorEvent.ERROR, errorCallback);
				sql.addEventListener(SQLEvent.RESULT, resultCallback);
				sql.execute();
			}
			else
			{
				// synchronous
				try
				{
					sql.execute();
					resultCallback(new SQLEvent(SQLEvent.RESULT));
				}
				catch (error:SQLError)
				{
					errorCallback(new SQLErrorEvent(SQLErrorEvent.ERROR, false, false, error));
				}
			}
		}
		
		public function checkSchema(callback:Function):void
		{
			var conn:SQLConnection = _dbConn;
			
			// callbacks
			var schemaCallback:Function = function (result:SQLSchemaResult  /* as we are using Responder */):void
			{
				// a schema must've been retrieved to get here - 
				// if table does not exist, errorCallback is called instead
				
				// current schema is fine
				if (callback != null)
					callback(new DBEvent(DBEvent.SUCCESSFUL));
			};
			var errorCallback:Function = function (error:SQLError /* as we are using Responder */):void
			{
				if (callback != null)
					callback(new DBEvent(DBEvent.ERROR, error.details));
			};
			
			if (isAsync)
			{
				_dbConn.loadSchema(SQLTableSchema, "StressTest", "main", true, 
					new Responder(schemaCallback, errorCallback));
			}
			else
			{
				// synchronous
				try
				{
					_dbConn.loadSchema(SQLTableSchema, "StressTest", "main", true);
					schemaCallback(_dbConn.getSchemaResult());
				}
				catch (error:SQLError)
				{
					errorCallback(error);
				}
			}
		}
		
		public function dispose():void
		{
			if (connection != null)
				connection.close();
		}
	}
}