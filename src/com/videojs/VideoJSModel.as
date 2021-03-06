package com.videojs{

    import com.videojs.events.VideoJSEvent;
    import com.videojs.events.VideoPlaybackEvent;
    import com.videojs.providers.*;
    import com.videojs.structs.ExternalErrorEventName;
    import com.videojs.structs.ExternalEventName;
    import com.videojs.structs.PlaybackType;
    import com.videojs.structs.PlayerMode;
    import com.videojs.vpaid.AdContainer;

    import flash.display.DisplayObject;
    import flash.events.Event;
    import flash.events.EventDispatcher;
    import flash.external.ExternalInterface;
    import flash.geom.Rectangle;
    import flash.media.SoundMixer;
    import flash.media.SoundTransform;
    import flash.utils.ByteArray;

    public class VideoJSModel extends EventDispatcher{

        private var _masterVolume:SoundTransform;
        private var _currentPlaybackType:String;
        private var _lastSetVolume:Number = 1;
        private var _provider:IProvider;

        // accessible properties
        private var _mode:String;
        private var _stageRect:Rectangle;
        private var _jsEventProxyName:String = "";
        private var _jsErrorEventProxyName:String = "";
        private var _backgroundColor:Number = 0;
        private var _backgroundAlpha:Number = 0;
        private var _volume:Number = 1;
        private var _autoplay:Boolean = false;
        private var _preload:Boolean = true;
        private var _loop:Boolean = false;
        private var _src:String = "";
        private var _bitrate:Number = 800;
        private var _width:Number = 0;
        private var _height:Number = 0;
        private var _duration:Number = 0;

        // ad support
        private var _adContainer:AdContainer;
        private var _adParameters:String = "";

        private static var _instance:VideoJSModel;

        public function VideoJSModel(pLock:SingletonLock){
            if (!pLock is SingletonLock) {
                throw new Error("Invalid Singleton access.  Use VideoJSModel.getInstance()!");
            }
            else{
                _mode = PlayerMode.VPAID;
                _currentPlaybackType = PlaybackType.HTTP;
                _masterVolume = new SoundTransform();
                _stageRect = new Rectangle(0, 0, 100, 100);
            }
        }

        public static function getInstance():VideoJSModel {
            if (_instance === null){
                _instance = new VideoJSModel(new SingletonLock());
            }
            return _instance;
        }

        public function get adContainer():AdContainer{
            return _adContainer;
        }

        public function set adContainer(pContainer: AdContainer):void{
            _adContainer = pContainer;
        }

        public function get mode():String{
            return _mode;
        }

        public function set mode(pMode:String):void {
            switch(pMode){
                case PlayerMode.VPAID:
                    _mode = pMode;
                    break;
                default:
                    broadcastEventExternally(ExternalErrorEventName.UNSUPPORTED_MODE);
            }
        }

        public function get jsEventProxyName():String{
            return _jsEventProxyName;
        }
        public function set jsEventProxyName(pName:String):void {
            _jsEventProxyName = cleanEIString(pName);
        }

        public function get jsErrorEventProxyName():String{
            return _jsErrorEventProxyName;
        }
        public function set jsErrorEventProxyName(pName:String):void {
            _jsErrorEventProxyName = cleanEIString(pName);
        }

        public function get stageRect():Rectangle{
            return _stageRect;
        }
        public function set stageRect(pRect:Rectangle):void {
            _stageRect = pRect;
        }

        public function appendBuffer(bytes:ByteArray):void {
            _provider.appendBuffer(bytes);
        }

        public function endOfStream():void {
            _provider.endOfStream();
        }

        public function abort():void {
            _provider.abort();
        }

        public function get backgroundColor():Number{
            return _backgroundColor;
        }
        public function set backgroundColor(pColor:Number):void {
            if(pColor < 0){
                _backgroundColor = 0;
            }
            else{
                _backgroundColor = pColor;
                broadcastEvent(new VideoPlaybackEvent(VideoJSEvent.BACKGROUND_COLOR_SET, {}));
            }
        }

        public function get backgroundAlpha():Number{
            return _backgroundAlpha;
        }
        public function set backgroundAlpha(pAlpha:Number):void {
            if(pAlpha < 0){
                _backgroundAlpha = 0;
            }
            else{
                _backgroundAlpha = pAlpha;
            }
        }

        public function get metadata():Object{
            if(_provider){
                return _provider.metadata;
            }
            return {};
        }

        public function get volume():Number{
            return _volume;
        }
        public function set volume(pVolume:Number):void {
            if(pVolume >= 0 && pVolume <= 1){
                _volume = pVolume;
            }
            else{
                _volume = 1;
            }
            _masterVolume.volume = _volume;
            SoundMixer.soundTransform = _masterVolume;
            _lastSetVolume = _volume;
            broadcastEventExternally(ExternalEventName.ON_VOLUME_CHANGE, _volume);
        }

        public function get duration():Number{
            return _duration;
        }

        public function set duration(value:Number):void {
            _duration = value;
        }

        public function get autoplay():Boolean{
            return _autoplay;
        }
        public function set autoplay(pValue:Boolean):void {
            _autoplay = pValue;
        }

        public function get src():String{
            if(_provider){
                return _provider.srcAsString;
            }
            return _src;
        }
        public function set src(pValue:String):void {
            _src = pValue;
            _currentPlaybackType = PlaybackType.HTTP;
            broadcastEventExternally(ExternalEventName.ON_SRC_CHANGE, _src);
            initProvider();
            if(_autoplay){
                _provider.play();
            }
            else if(_preload){
                _provider.load();
            }
        }

        public function get adParameters():String{
            return _adParameters;
        }
        public function set adParameters(pValue:String):void {
            _adParameters = pValue;
        }
        public function get bitrate():Number{
            return _bitrate;
        }
        public function set bitrate(pValue:Number):void {
            _bitrate = pValue;
        }
        public function get width():Number{
            return _width;
        }
        public function set width(pValue:Number):void {
            _width = pValue;
        }
        public function get height():Number{
            return _height;
        }
        public function set height(pValue:Number):void {
            _height = pValue;
        }

        /**
         * This is used to distinguish a _src that's being set from incoming flashvars,
         * and mirrors the normal setter WITHOUT dispatching the 'onsrcchange' event.
         *
         * @param pValue
         *
         */
        public function set srcFromFlashvars(pValue:String):void {
            _src = pValue;
            _currentPlaybackType = PlaybackType.HTTP
            initProvider();
            if(_autoplay){
                _provider.play();
            }
            else if(_preload){
                _provider.load();
            }
        }

        public function get hasEnded():Boolean{
            if(_provider){
                return _provider.ended;
            }
            return false;
        }

        /**
         * Returns the playhead position of the current video, in seconds.
         * @return
         *
         */
        public function get time():Number{
            if(_provider){
                return _provider.time;
            }
            return 0;
        }

        public function get muted():Boolean{
            return (_volume == 0);
        }
        public function set muted(pValue:Boolean):void {
            if(pValue){
                var __lastSetVolume:Number = _lastSetVolume;
                volume = 0;
                _lastSetVolume = __lastSetVolume;
            }
            else{
                volume = _lastSetVolume;
            }
        }

        public function get seeking():Boolean{
            if(_provider){
                return _provider.seeking;
            }
            return false;
        }

        public function get networkState():int{
            if(_provider){
                return _provider.networkState;
            }
            return 0;
        }

        public function get readyState():int{
            if(_provider){
                return _provider.readyState;
            }
            return 0;
        }

        public function get preload():Boolean{
            return _preload;
        }
        public function set preload(pValue:Boolean):void {
            _preload = pValue;
        }

        public function get loop():Boolean{
            return _loop;
        }
        public function set loop(pValue:Boolean):void {
            _loop = pValue;
        }

        public function get buffered():Number{
            /*
            if(_provider){
                return _provider.buffered;
            }
            */
            return 0;
        }

        /**
         * Returns the total number of bytes loaded for the current video.
         * @return
         *
         */
        public function get bufferedBytesEnd():int{
            if(_provider){
                return _provider.bufferedBytesEnd;
            }
            return 0;
        }

        /**
         * Returns the total size of the current video, in bytes.
         * @return
         *
         */
        public function get bytesTotal():int{
            if(_provider){
                return _provider.bytesTotal;
            }
            return 0;
        }

        public function get playing():Boolean{
            if(_provider){
                return _provider.playing;
            }
            return false;
        }

        public function get paused():Boolean{
            if(_provider){
                return _provider.paused;
            }
            return true;
        }

        /**
         * Allows this model to act as a centralized event bus to which other classes can subscribe.
         *
         * @param e
         *
         */
        public function broadcastEvent(e:Event):void {
            dispatchEvent(e);
        }

        /**
         * This is an internal proxy that allows instances in this swf to broadcast events to a JS proxy function, if one is defined.
         * @param args
         *
         */
        public function broadcastEventExternally(... args):void {
            if(_jsEventProxyName != ""){
                if(ExternalInterface.available){
                    var __incomingArgs:* = args as Array;
                    var __newArgs:Array = [_jsEventProxyName, ExternalInterface.objectID].concat(__incomingArgs);
                    var __sanitizedArgs:Array = cleanObject(__newArgs);
                    // ExternalInterface.call("console.info", "vpaidmodel", 'broadcastEventExternally', String(__sanitizedArgs));
                    ExternalInterface.call.apply(null, __sanitizedArgs);
                }
            }
        }

        /**
         * This is an internal proxy that allows instances in this swf to broadcast error events to a JS proxy function, if one is defined.
         * @param args
         *
         */
        public function broadcastErrorEventExternally(... args):void {
            if(_jsErrorEventProxyName != ""){
                if(ExternalInterface.available){
                    var __incomingArgs:* = args as Array;
                    var __newArgs:Array = [_jsErrorEventProxyName, ExternalInterface.objectID].concat(__incomingArgs);
                    var __sanitizedArgs:Array = cleanObject(__newArgs);
                    // ExternalInterface.call("console.info", "vpaidmodel", 'broadcastErrorEventExternally', String(__sanitizedArgs));
                    ExternalInterface.call.apply(null, __sanitizedArgs);
                }
            }
        }

        /**
         * Loads the video in a paused state.
         *
         */
        public function load():void {
            if(_provider){
                _provider.load();
            }
        }

        /**
         * Loads the video and begins playback immediately.
         *
         */
        public function play():void {
            if(_provider){
                _provider.play();
            }
        }

        /**
         * Pauses video playback.
         *
         */
        public function pause():void {
            if(_provider){
                _provider.pause();
            }
        }

        /**
         * Resumes video playback.
         *
         */
        public function resume():void {
            if(_provider){
                _provider.resume();
            }
        }

        /**
         * Seeks the currently playing video to the closest keyframe prior to the value provided.
         * @param pValue
         *
         */
        public function seekBySeconds(pValue:Number):void {
            if(_provider){
                _provider.seekBySeconds(pValue);
            }
        }

        /**
         * Seeks the currently playing video to the closest keyframe prior to the percent value provided.
         * @param pValue A float from 0 to 1 that represents the desired seek percent.
         *
         */
        public function seekByPercent(pValue:Number):void {
            if(_provider){
                _provider.seekByPercent(pValue);
            }
        }

        /**
         * Stops video playback, clears the video element, and stops any loading proceeses.
         *
         */
        public function stop():void {
            if(_provider){
                _provider.stop();
            }
        }

        public function hexToNumber(pHex:String):Number{
            var __number:Number = 0;
            // clean it up
            if(pHex.indexOf("#") != -1){
                pHex = pHex.slice(pHex.indexOf("#")+1);
            }
            if(pHex.length == 6){
                __number = Number("0x"+pHex);
            }
            return __number;
        }

        public function humanToBoolean(pValue:*):Boolean{
            if(String(pValue) == "true" || String(pValue) == "1"){
                return true;
            }
            else{
                return false;
            }
        }

        /**
         * Removes dangerous characters from a user-provided string that will be passed to ExternalInterface.call()
         *
         */
        public function cleanEIString(pString:String):String{
            return pString.replace(/[^A-Za-z0-9_.]/gi, "");
        }

        /**
         * Recursive function to sanitize an object (or array) before passing to ExternalInterface.call()
         */
        private function cleanObject(obj:*):*{
            if (obj is String) {
                return obj.split("\\").join("\\\\");
            } else if (obj is Array) {
                var __sanitizedArray:Array = new Array();

                for each (var __item:* in obj){
                    __sanitizedArray.push(cleanObject(__item));
                }

                return __sanitizedArray;
            } else if (typeof(obj) == 'object') {
                var __sanitizedObject:Object = new Object();

                for (var __i:* in obj){
                    __sanitizedObject[__i] = cleanObject(obj[__i]);
                }

                return __sanitizedObject;
            } else {
                return obj;
            }
        }

        private function initProvider():void {
            if(_provider){
                _provider.die();
                _provider = null;
            }
            var __src:Object;
            // We need to determine which provider to load, based on the values of our exposed properties.
            switch(_mode){
                case PlayerMode.VPAID:

                    if(_currentPlaybackType == PlaybackType.HTTP){
                        __src = {
                            path: _src
                        };
                        _provider = new VPAIDProvider();
                        _provider.attachAdContainer(_adContainer);
                        _provider.init(__src, _autoplay);
                    }

                    break;

                default:
                    broadcastEventExternally(ExternalErrorEventName.UNSUPPORTED_MODE);
            }
        }
    }
}


/**
 * @internal This is a private class declared outside of the package
 * that is only accessible to classes inside of this file
 * file.  Because of that, no outside code is able to get a
 * reference to this class to pass to the constructor, which
 * enables us to prevent outside instantiation.
 *
 * We do this because Actionscript doesn't allow private constructors,
 * which prevents us from creating a "true" singleton.
 *
 * @private
 */
class SingletonLock {}
