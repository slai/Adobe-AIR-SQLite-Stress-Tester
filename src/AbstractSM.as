package 
{
	import flash.errors.IllegalOperationError;
	import flash.events.Event;
	import flash.events.TimerEvent;
	import flash.utils.Dictionary;
	import flash.utils.Timer;

	public class AbstractSM
	{
		// instance variables
		protected var _active:Boolean;
		protected var _timerInterval:Number;
		protected var _timer:Timer;
		protected var _progressCallback:Function;
		protected var _errorCallback:Function;
		protected var _endCallback:Function;
		protected var _pauseAfter:Boolean;
		protected var _currentState:Function;
		protected var _runProps:Object;
		
		// state table
		protected var _stateTable:Dictionary;
		
		public function AbstractSM()
		{
			// init variables
			_active = false;
			_timerInterval = 0;
			_timer = null;
			_progressCallback = null;
			_errorCallback = null;
			_endCallback = null;
			_pauseAfter = false;
			_currentState = null;
			_runProps = null;
		}
		
		// properties
		public function get active():Boolean
		{
			return _active;
		}
		
		protected function setActive(value:Boolean):void 
		{
			_active = value;
		}
		
		public function get timerInterval():Number
		{
			return _timerInterval;
		}
		
		public function set timerInterval(value:Number):void
		{
			_timerInterval = value;
		}
		
		protected function get currentState():Function
		{
			return _currentState;
		}
		
		protected function set currentState(value:Function):void
		{
			_currentState = value;
		}
		
		// methods
		public function start(progressCallback:Function, errorCallback:Function, endCallback:Function):void
		{
			// if currently active, give up now
			if (active)
				throw new IllegalOperationError("The state machine is already running.");

			_progressCallback = progressCallback;
			_errorCallback = errorCallback;
			_endCallback = endCallback;
			
			// reset machine to the start
			currentState = start;
			
			// reset run props
			_runProps = { };
			
			// turn machine on!
			setActive(true);
			_pauseAfter = false;
			
			// create a timer if necessary
			if (timerInterval > 0)
			{
				_timer = new Timer(timerInterval);
				_timer.addEventListener(TimerEvent.TIMER, nextState);
				_timer.start();
			}
			else
			{
				_timer = null;
				nextState();
			}
		}
		
		// call this if the current state wants the state machine to pause after it finishes.
		// this is useful if the next state is triggered by a callback, e.g. after HTTP call.
		protected function pauseAfter():void
		{
			_pauseAfter = true;
		}
		
		// it is necessary to call this after a pauseAfter call to start the 
		// machine again because timer events that are delayed still get called
		// eventually, and hence it is necessary to for nextState to ignore calls
		// from the timer during this period.
		// http://stackoverflow.com/questions/1840807
		protected function resume(e:Event=null):void
		{
			_pauseAfter = false;
			
			// start timer again - it should not be running
			// as it would have been stopped by a pauseAfter call
			if (_timer && !_timer.running)
				_timer.start();
		}
		
		protected function jumpToState(stateFunction:Function):void
		{
			currentState = stateFunction;
			currentState();
		}
		
		protected function errorOccurred(errorCode:int, errorMessage:String):void 
		{
			// let someone know if someone cares
			if (_errorCallback != null) _errorCallback(errorCode, errorMessage);
		}
		
		protected function progressChanged(message:String):void 
		{
			// let someone know if someone cares
			if (_progressCallback != null) _progressCallback(message);
		}
		
		protected function nextState(e:Event = null):void
		{
			if (!active)
				return;
			
			// currently pausing
			if (_pauseAfter)
				return;
			
			while (true)
			{
				// check if the current state is the end state
				if (_currentState == endState) return;
				
				// call the next state
				if (_stateTable[_currentState] == undefined)
				{
					// there is no next state. State machine not properly designed.
					trace("[SM] : No next state in state table.");
					
					// jump to the end
					jumpToState(endState);
				}
				else
				{
					jumpToState(_stateTable[_currentState]);
				}
				
				// check if a pause has been requested
				// this assumes even HTTP calls do not pre-empt the system, otherwise pause 
				// may occur after the wrong call.
				if (_pauseAfter) 
				{
					// stop timer
					if (_timer && _timer.running) 
						_timer.stop();
					
					break;
				}
				
				// don't loop; timer will call me again later
				if (_timer && _timer.running)
					break;
			}
		}
		
		protected function endState():void
		{
			// all done
			setActive(false);
			
			// destroy timer
			if (_timer)
			{
				_timer.stop();
				_timer = null;
			}
			
			// let someone know if someone cares
			if (_endCallback != null) _endCallback();
		}
	}
}