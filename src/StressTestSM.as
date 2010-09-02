package
{
	import flash.utils.Dictionary;
	
	import mx.utils.UIDUtil;
	
	public class StressTestSM extends AbstractSM
	{
		private const SCHEMA_CHECK_INTERVAL:int = 5;
		
		private var _recordsCount:int;
		private var _dbInstance:DBInstance;
		private var _doSchemaChecks:Boolean;
		private var _getAfterInsertion:Boolean;
		
		public function StressTestSM(recordsCount:int, dbInstance:DBInstance, 
									 doSchemaChecks:Boolean=false, getAfterInsertion:Boolean=false)
		{
			super();
			
			// validate
			if (recordsCount <= 0)
				throw new ArgumentError("The record count must be positive.");
			
			if (dbInstance == null)
				throw new ArgumentError("A valid DB instance must be specified.");
			
			_recordsCount = recordsCount;
			_dbInstance = dbInstance;
			_doSchemaChecks = doSchemaChecks;
			_getAfterInsertion = getAfterInsertion;
			
			// state table
			_stateTable = new Dictionary();
			// current state -> next state function, or next state evaluator
			_stateTable[start] = init;
			
			_stateTable[init] = isDBReadyDecision;
			_stateTable[dbNotReady] = isDBReadyDecision;
			_stateTable[dbReady] = nextRecordDecision;
			_stateTable[createRecord] = saveRecord;
			_stateTable[saveRecord] = savedRecordDecision;
			_stateTable[saveError] = testError;
			_stateTable[saveSuccessful] = getRecordDecision;
			
			_stateTable[doGetRecord] = getRecord;
			_stateTable[doNotGetRecord] = nextRecordDecision;
			
			_stateTable[getRecord] = gotRecordDecision;
			_stateTable[getRecordError] = testError;
			_stateTable[getRecordSuccessful] = nextRecordDecision;
			
			_stateTable[startSchemaCheck] = schemaCheckedDecision;
			_stateTable[schemaCheckError] = testError;
			_stateTable[schemaCheckSuccessful] = nextRecordDecision;
			
			_stateTable[testError] = endState;
			_stateTable[testCompleted] = endState;
		}
		
		private function init():void
		{
			_runProps["count"] = 0;
			_runProps["schemaCheckCount"] = 0;
			_runProps["schemaCheckRandomizer"] = Math.round(Math.random() * SCHEMA_CHECK_INTERVAL);
		}
		
		private function isDBReadyDecision():void
		{
			// check if database is ready
			if (!_dbInstance.ready)
			{
				jumpToState(dbNotReady);
			}
			else
			{
				jumpToState(dbReady);
			}
		}
		
		private function dbNotReady():void
		{
			// placeholder state
		}
		
		private function dbReady():void
		{
			// placeholder state
		}
		
		private function nextRecordDecision():void
		{
			if (_runProps["count"] == _recordsCount)
			{
				jumpToState(testCompleted);
			}
			else
			{
				if (_doSchemaChecks)
				{
					// check if time to check schema
					var i:int = _runProps["count"] + _runProps["schemaCheckRandomizer"];
					if (i % SCHEMA_CHECK_INTERVAL == 0)
					{
						// check if schema has already been checked this time round
						if (Math.round(i / SCHEMA_CHECK_INTERVAL) > _runProps["schemaCheckCount"])
						{
							// has not, check now!
							jumpToState(startSchemaCheck);
							return;
						}
					}
				}
				
				jumpToState(createRecord);
			}
		}
		
		private function createRecord():void
		{
			_runProps["count"]++;
			
			progressChanged("Creating record " + _runProps["count"] + "...");
			
			var record:DBRecord = new DBRecord();
			record.title = UIDUtil.createUID();
			record.number = Math.round(Math.random() * new Date().time);
			record.date = new Date();
			
			_runProps["record"] = record;
		}
		
		private function saveRecord():void
		{	
			progressChanged("Saving record " + _runProps["count"] + "...");
			
			pauseAfter();
			_dbInstance.save(_runProps["record"], saveRecordCallback);
		}
		
		private function saveRecordCallback(event:DBEvent):void
		{
			progressChanged("Saved record " + _runProps["count"] + ".");
			
			_runProps["savedDBEvent"] = event;
			
			resume();
		}
		
		private function savedRecordDecision():void
		{
			var event:DBEvent = DBEvent(_runProps["savedDBEvent"]);
			
			if (event.type == DBEvent.ERROR)
			{
				errorOccurred(0, "Error occurred when saving record " + _runProps["count"] + " - " + event.message);
				jumpToState(saveError);
			}
			else
			{
				// successful
				jumpToState(saveSuccessful);
			}
		}
		
		private function saveError():void
		{
			// placeholder state
		}
		
		private function saveSuccessful():void
		{
			// placeholder state
		}
		
		private function getRecordDecision():void
		{
			if (_getAfterInsertion)
			{
				jumpToState(doGetRecord);
			}
			else
			{
				jumpToState(doNotGetRecord);
			}
		}
		
		private function doGetRecord():void
		{
			// placeholder state
		}
		
		private function doNotGetRecord():void
		{
			// placeholder state
		}
		
		private function getRecord():void
		{
			progressChanged("Getting record " + _runProps["count"] + "...");
			
			pauseAfter();
			_dbInstance.getByTitle(_runProps["record"].title, getRecordCallback);
		}
		
		private function getRecordCallback(event:DBEvent):void
		{
			progressChanged("Got record " + _runProps["count"] + ".");
			
			_runProps["getRecordDBEvent"] = event;
			
			resume();
		}
		
		private function gotRecordDecision():void
		{
			var event:DBEvent = DBEvent(_runProps["getRecordDBEvent"]);
			
			if (event.type == DBEvent.ERROR)
			{
				errorOccurred(0, "Error occurred when getting record " + _runProps["count"] + " - " + event.message);
				jumpToState(getRecordError);
			}
			else
			{
				// successful
				// check if the record gotten matches
				var record:DBRecord = DBRecord(event.object);
				var originalRecord:DBRecord = DBRecord(_runProps["record"]);
				
				if (record == null)
				{
					// no record for some reason
					jumpToState(getRecordError);
					return;
				}
				
				progressChanged("Got record " + _runProps["count"] + " - " + record.title);
				
				// the date comparison needs a bit of leeway, as the retrieved date can be up to a second off
				if (record.id != originalRecord.id || record.title != originalRecord.title 
					|| record.number != originalRecord.number || Math.abs(record.date.time - originalRecord.date.time) > 1000)
				{
					// record did not match
					errorOccurred(0, "Retrieved record does not match inserted contents.");
					jumpToState(getRecordError);
					return;
				}
				
				jumpToState(getRecordSuccessful);
			}
		}
		
		private function getRecordError():void
		{
			// placeholder state
		}
		
		private function getRecordSuccessful():void
		{
			// placeholder state
		}
		
		private function startSchemaCheck():void
		{
			_runProps["schemaCheckCount"]++;
			
			progressChanged("Checking schema x" + _runProps["schemaCheckCount"] + "...");
			
			pauseAfter();
			_dbInstance.checkSchema(schemaCheckCallback);
		}
		
		private function schemaCheckCallback(event:DBEvent):void
		{
			progressChanged("Checked schema x" + _runProps["schemaCheckCount"] + ".");
			
			_runProps["checkSchemaDBEvent"] = event;
			
			resume();
		}
		
		private function schemaCheckedDecision():void
		{
			var event:DBEvent = DBEvent(_runProps["checkSchemaDBEvent"]);
			
			if (event.type == DBEvent.ERROR)
			{
				errorOccurred(0, "Error occurred when checking schema x" + _runProps["schemaCheckCount"] + " - " + event.message);
				jumpToState(schemaCheckError);
			}
			else
			{
				// successful
				jumpToState(schemaCheckSuccessful);
			}
		}
		
		private function schemaCheckError():void
		{
			// placeholder state
		}
		
		private function schemaCheckSuccessful():void
		{
			// placeholder state
		}
		
		private function testError():void
		{
			// placeholder state
		}
		
		private function testCompleted():void
		{
			// placeholder state
		}
	}
}