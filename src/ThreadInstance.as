package
{
	import flash.errors.IllegalOperationError;

	public class ThreadInstance
	{
		// public vars
		[Bindable]
		public var index:int;
		[Bindable]
		public var startTime:Date;
		[Bindable]
		public var endTime:Date;
		[Bindable]
		public var timeTaken:Number; // in seconds
		[Bindable]
		public var progressMsg:String;
		
		private var _dbInstance:DBInstance;
		private var _sm:StressTestSM;
		
		public function ThreadInstance(threadIndex:int, dbInstance:DBInstance)
		{
			// validate
			if (threadIndex < 0)
				throw new ArgumentError("The thread index must be positive.");
			
			if (dbInstance == null)
				throw new ArgumentError("A database instance must be specified.");
			
			// init vars
			index = threadIndex;
			startTime = null;
			endTime = null;
			timeTaken = NaN;
			progressMsg = "";
			
			_dbInstance = dbInstance;
			_sm = null;
		}
		
		public function get running():Boolean
		{
			if (_sm == null)
				return false;
			
			return _sm.active;
		}
		
		public function start(recordsCount:int, timerInterval:Number, doSchemaChecks:Boolean, 
							  getAfterInsertion:Boolean, endCallback:Function):void
		{
			// check if already running
			if (_sm != null)
			{
				if (_sm.active)
					throw new IllegalOperationError("Already running!");
				else
					_sm = null;
			}
			
			_sm = new StressTestSM(recordsCount, _dbInstance, doSchemaChecks, getAfterInsertion);
			_sm.timerInterval = timerInterval;
			
			// callbacks
			var progressCallback:Function = function (message:String):void
			{
				progressMsg = message;
			};
			var errorCallback:Function = function (code:int, message:String):void
			{
				progressMsg = "ERROR: " + message;
			};
			var wrappedEndCallback:Function = function ():void
			{
				endTime = new Date();
				timeTaken = (endTime.time - startTime.time) / 1000; // in seconds
				if (endCallback != null) endCallback();
			};
			
			_sm.start(progressCallback, errorCallback, wrappedEndCallback);
			startTime = new Date();
		}
		
		public function dispose():void
		{
			_sm = null;
		}
	}
}