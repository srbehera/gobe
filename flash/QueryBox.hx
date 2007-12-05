import flash.display.Sprite;
import flash.display.MovieClip;
import flash.display.Loader;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.text.TextField;

import flash.net.URLRequest;
import flash.net.URLLoader;
import flash.text.TextFormat;
import flash.text.StyleSheet;
import flash.display.Bitmap;
import AnnoInput;



class QueryBox extends Sprite {
    private var _width:Int;
    private var _il:Loader;
    private var _ilplus:Loader;
    private var _ilminus:Loader;
    private var _ilclear:Loader;
    private var _ilsave:Loader;
    private var _height:Int;
    private var _taper:Int;
    private var _if:Loader;
    //private var _close:Sprite;
    

    public  var view:String;
    public  var gobe:Gobe;
    public  var freezable:Bool;
    public  var  container:MovieClip;
    public  var info:TextField;
    public  var anno:AnnoInput;
    public  var anno_mc:MovieClip;
    public  var plus:Sprite;
    public  var clear_sprite:Sprite;
    public  var save_sprite:Sprite;
    public  var tf_size:TextField;
    public  var minus:Sprite;
    public  var line_width:Int;

    public function show(){
        if(this.view == "INFO" && this.contains(plus)){ trace('nothing to do'); return; }
        if(!this.contains(plus)){
            trace('adding first time;');
            var g = this.graphics;
            g.lineStyle(1,0x777777);
            g.beginFill(0xcccccc);
            g.drawRoundRect(0, 0, _width + 1, _height + 2 * _taper, _taper);
            g.endFill();
            //this.addChild(_close);
            this.addChild(plus);
            this.addChild(clear_sprite);
        
            if(freezable){ this.addChild(save_sprite); }
            this.addChild(minus);
            this.addChild(tf_size);
            this.container.addChild(info);
        }
        while(this.container.numChildren != 0 && this.container.getChildAt(0) != info){
            this.container.removeChildAt(0);
        }
        if(this.view != "INFO"){
            this.container.addChild(info);
        }
        this.view = "INFO";
    }

    public static function main(){
        flash.Lib.current.stage.scaleMode = flash.display.StageScaleMode.NO_SCALE;
        flash.Lib.current.stage.align     = flash.display.StageAlign.TOP_LEFT;
        haxe.Firebug.redirectTraces();

        var qbx = new QueryBox('../../', true, new Gobe());
        qbx.show();
    }


    public function new(base_url:String, freezable:Bool, gobe:Gobe){
        super();
        this.gobe = gobe;
        this.freezable =freezable;
        _width  = 360;
        _height = 630;
        view = "INFO";
        _taper  = 20;
        line_width = 1;

        var css = new StyleSheet();
        css.setStyle( "a", {
                            fontFamily  : "Arial",
                            fontSize    : 18,
                            fontStyle   : 'underline',
                            color       : '#0000ff'
                        });
        css.setStyle( "docs", {
                            fontFamily  : "Arial",
                            fontSize    : 16,
                            display     : 'inline'
                        });
        css.setStyle( "p", {
                            fontFamily  : "Arial",
                            fontSize    : 13,
                            display     : 'inline'
                        });

        css.setStyle('text', { fontSize: 12, display:'inline'});

        css.setStyle('sequence', { fontSize: 11, display:'inline'});

        addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent){
            if(Std.is(e.target,QueryBox)){ 
                e.target.startDrag();
                flash.Lib.current.setChildIndex(e.target, flash.Lib.current.numChildren - 1);
            }
        });
        addEventListener(MouseEvent.MOUSE_UP, function(e:MouseEvent){
            if(Std.is(e.target,QueryBox)){ e.target.stopDrag(); }
        });

        container = new MovieClip();
        addChild(container);

        info = new TextField();
        info.wordWrap   = true;
        info.border     = false;
        info.styleSheet = css;
        info.scrollH    = 10;
        info.scrollV    = 30;

        info.x = 1;
        info.y = _taper -1;

        info.width  = _width;
        info.height = _height;

        info.mouseWheelEnabled = true;
        
        info.background      = true;
        info.backgroundColor = 0xFFFFFF;
                               
        anno_mc = new MovieClip();
        anno_mc.y = _taper - 1;
        anno_mc.x = 10;
        anno = new AnnoInput(anno_mc, 2, this.gobe);

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
        plus = new Sprite();
        minus = new Sprite();
        plus.addEventListener(MouseEvent.CLICK, plusClick);
        minus.addEventListener(MouseEvent.CLICK, minusClick);

        clear_sprite = new Sprite();


        if(freezable){
            save_sprite = new Sprite();
            _ilsave = new Loader();
            _ilsave.contentLoaderInfo.addEventListener(Event.COMPLETE, handleSaveLoaded);
            _ilsave.load(new URLRequest(base_url + "static/save.gif"));
            save_sprite.addEventListener(MouseEvent.CLICK, viewClick);
        }

        
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

    private function handleSaveLoaded(e:Event){
        save_sprite.addChild(cast(_ilsave.content,Bitmap));
        save_sprite.x = 62;
        save_sprite.y = 1.5;
    }

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
        info.htmlText =  e.target.data;
    }
    
    public function viewClick(e:MouseEvent){
        if(view == "INFO") { view = "ANNO"; }
        while(this.container.numChildren != 0){
            this.container.removeChildAt(0);
        }
        this.container.addChild(anno_mc);

    }

    public function plusClick(e:MouseEvent){
        if( line_width > 6){ return; }
        line_width += 1;
        tf_size.htmlText = 'line width: <b>' + line_width + '</b>';
    }
    public function minusClick(e:MouseEvent){
        if( line_width < 1){ return; }
        line_width -= 1;
        tf_size.htmlText = 'line width: <b>' + line_width + '</b>';
    }


}

