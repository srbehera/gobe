import flash.display.Sprite;
import flash.display.Loader;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.text.TextField;

import flash.net.URLRequest;
import flash.net.URLLoader;
import flash.text.TextFormat;
import flash.text.StyleSheet;
import flash.display.Bitmap;



class QueryBox extends Sprite {
    private var _width:Int;
    private var _il:Loader;
    private var _ilplus:Loader;
    private var _ilminus:Loader;
    private var _ilclear:Loader;
    private var _height:Int;
    private var _taper:Int;
    private var _if:Loader;
    //private var _close:Sprite;
    

    public  var freeze:Sprite;
    public  var tf:TextField;
    public  var plus:Sprite;
    public  var clear_sprite:Sprite;
    public  var tf_size:TextField;
    public  var minus:Sprite;
    public  var line_width:Int;
    public  var css:StyleSheet;

    public function show(){
        var g = this.graphics;
        g.lineStyle(1,0x777777);
        g.beginFill(0xcccccc);
        g.drawRoundRect(0, 0, _width + 1, _height + 2 * _taper, _taper);
        g.endFill();
        this.addChild(tf);
        this.addChild(freeze);
        //this.addChild(_close);
        this.addChild(plus);
        this.addChild(clear_sprite);
        this.addChild(minus);
        this.addChild(tf_size);
    }

    public static function main(){
        flash.Lib.current.stage.scaleMode = flash.display.StageScaleMode.NO_SCALE;
        flash.Lib.current.stage.align     = flash.display.StageAlign.TOP_LEFT;
        haxe.Firebug.redirectTraces();

        var qbx = new QueryBox('../../', true);
        qbx.show();
    }


    public function new(base_url:String, freezable:Bool){
        super();
        _width  = 360;
        _height = 630;
        _taper  = 20;
        line_width = 1;

        css = new StyleSheet();
        css.setStyle( "p", {
                            fontFamily  : "Arial",
                            fontSize    : 13,
                            display     : "inline"
                        });
        css.setStyle('sequence', { fontSize: 11, display:'inline'});

        addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent){
            if(Std.is(e.target,QueryBox)){ e.target.startDrag(); }
        });
        addEventListener(MouseEvent.MOUSE_UP, function(e:MouseEvent){
            if(Std.is(e.target,QueryBox)){ e.target.stopDrag(); }
        });


        tf = new TextField();
        tf.wordWrap   = true;
        tf.border     = false;
        tf.styleSheet = css;
        tf.scrollH    = 10;
        tf.scrollV    = 30;

        tf.x = 1;
        tf.y = _taper -1;

        tf.width  = _width;
        tf.height = _height;

        tf.mouseWheelEnabled = true;
        
        tf.background      = true;
        tf.backgroundColor = 0xFFFFFF;


        tf_size = new TextField();
        tf_size.wordWrap   = true;
        tf_size.border     = false;
        tf_size.width      = 65;
        tf_size.height     = 30;
        tf_size.htmlText   = "line width: <b>1</b>";
        tf_size.x          = _width - 100;
        tf_size.y          = 0;


        var loader = new URLLoader();
        loader.addEventListener(Event.COMPLETE, handleHtmlLoaded);
        loader.load(new URLRequest(base_url + "docs/textfield.html"));
        freeze = new Sprite();
        plus = new Sprite();
        minus = new Sprite();
        plus.addEventListener(MouseEvent.CLICK, plusClick);
        minus.addEventListener(MouseEvent.CLICK, minusClick);

        clear_sprite = new Sprite();


        if(freezable){
            _if = new Loader();
            _if.contentLoaderInfo.addEventListener(Event.COMPLETE, handleFreezeLoaded);
            _if.load(new URLRequest(base_url + "static/save.gif"));
        }

    /*
        _close = new Sprite();
    public function hide(){
        this.removeChild(tf);
        this.removeChild(_close);
        this.removeChild(plus);
        this.removeChild(freeze);
        this.removeChild(minus);
        this.removeChild(clear_sprite);
        this.removeChild(tf_size);
        this.graphics.clear();
    }
    */
            
        //_close.addEventListener(MouseEvent.CLICK, function (e:MouseEvent){
        //    e.target.parent.hide();
        //});


        //_il = new Loader();
        //_il.contentLoaderInfo.addEventListener(Event.COMPLETE, handleCloseLoaded);
        //_il.load(new URLRequest(base_url + "static/close_button.gif"));

        
        _ilplus = new Loader();
        _ilplus.contentLoaderInfo.addEventListener(Event.COMPLETE, handlePlusLoaded);
        _ilplus.load(new URLRequest(base_url + "static/plus.gif"));



        _ilminus = new Loader();
        _ilminus.contentLoaderInfo.addEventListener(Event.COMPLETE, handleMinusLoaded);
        _ilminus.load(new URLRequest(base_url + "static/minus.gif"));

       
        _ilclear = new Loader();
        _ilclear.contentLoaderInfo.addEventListener(Event.COMPLETE, handleClearLoaded);
        _ilclear.load(new URLRequest(base_url + "static/clear_button.gif"));

        flash.Lib.current.addChild(this);

    }
    private function handleClearLoaded(e:Event){
        clear_sprite.addChild(cast(_ilclear.content,Bitmap));
        clear_sprite.x = 12;
        clear_sprite.y = 1.5;
    }

    private function handleFreezeLoaded(e:Event){
        freeze.addChild(cast(_if.content,Bitmap));
        freeze.x = 90;
        freeze.y = 1;

    }
    //private function handleCloseLoaded(e:Event){
    //    _close.addChild(cast(_il.content,Bitmap));
    //    _close.x = _width - 20;
    //    _close.y = 2.5;
    //}
    private function handlePlusLoaded(e:Event){
        plus.addChild(cast(_ilplus.content,Bitmap));
        plus.x = _width - 20;
        plus.y = 2.5;
    }
    private function handleMinusLoaded(e:Event){
        minus.addChild(cast(_ilminus.content,Bitmap));
        minus.x = _width - 35;
        minus.y = 2.5;
    }
    public function handleHtmlLoaded(e:Event){
        tf.text = "'" + e.target.data + "'";
    }

    public function plusClick(e:MouseEvent){
        if( line_width > 6){ return; }
        line_width += 1;
        trace(line_width);
        tf_size.htmlText = 'line width: <b>' + line_width + '</b>';
    }
    public function minusClick(e:MouseEvent){
        if( line_width < 1){ return; }
        line_width -= 1;
        tf_size.htmlText = 'line width: <b>' + line_width + '</b>';
    }


}

