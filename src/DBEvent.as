package
{
	import flash.events.Event;
	
	public class DBEvent extends Event
	{
		public static const SUCCESSFUL:String = "successful";
		public static const ERROR:String = "error";
		
		public var message:String;
		public var object:*;
		
		public function DBEvent(type:String, message:String="", object:*=null, bubbles:Boolean=false, cancelable:Boolean=false)
		{
			this.message = message;
			this.object = object;
			
			super(type, bubbles, cancelable);
		}
	}
}