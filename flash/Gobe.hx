import flash.display.MovieClip;
import flash.display.Sprite;
import flash.display.Shape;
import flash.display.Loader;
import flash.display.StageScaleMode;
import flash.display.StageAlign;
import flash.display.Bitmap;
import flash.display.BitmapData;
import flash.events.Event;
import flash.events.MouseEvent;
import flash.events.TimerEvent;
import flash.geom.Point;
import flash.net.URLRequest;
import flash.net.URLLoader;
import flash.system.LoaderContext;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.StyleSheet;
import flash.utils.Timer;
import Json;


class Gobe extends Sprite {

    public static var ctx = new LoaderContext(true);
    private var line_width:Int;

    // base_url and n are sent in on the url.
    private var base_url:String;
    private var n:Int;
    private var img:String;
    private var tmp_dir:String;

    private var _heights:Array<Int>;

    private var rect:QueryBox;
    private var _all:Bool;
    private var imgs:Array<GImage>;
    private var gcoords:Array<Array<Int>>;
    private var QUERY_URL:String;
    private var _image_titles:Array<String>;


    public function onClick(e:MouseEvent) {
        if(e.target._bitmap.getPixel(e.localX, e.localY)){
            query(e);
        }
    }

    private function query(e:MouseEvent){
        var img = e.target.url;
        var url = this.QUERY_URL + '&y=' + e.localY + '&img=' + img + '&db=' 
                      + img.substr(0,img.lastIndexOf('_')) + '.sqlite';
        

        if(! e.altKey){
            this.graphics.clear();
            flash.Lib.current.graphics.clear();
            rect.tf.text = '';
            for(img in this.imgs){
                img.graphics.clear();
            }
        }
        if(e.shiftKey) {
            url      += '&all=1';
            this._all = true;
        }
        else{
            url      += '&x=' + e.localX;
            this._all = false;
        }

        trace(url);
        var queryLoader = new URLLoader();
        queryLoader.addEventListener(Event.COMPLETE, handleQueryReturn);
        queryLoader.load(new URLRequest(url));
    }

    private function handleQueryReturn(e:Event){
        var json:Array<Dynamic> = Json.decode(e.target.data).resultset;
        gcoords = [];
        var pair:Hash<Dynamic>;
        // TODO: create another page in front of hte images for the
        // hsp outlines and use an object for each rectangle so it
        // can respond to mouseover events.
        var g = flash.Lib.current.graphics;
        
        for(pair in json){
            g.lineStyle(line_width);
            rect.tf.htmlText = "<font color='#0000ff'><u><a target='_blank' href='" + pair.link + "'>full annotation</a></u></font>&#10;&#10;";
            rect.tf.htmlText += pair.annotation;
            for(hsp in Reflect.fields(pair.features)){
                 
                var coords:Array<Dynamic> = Reflect.field(pair.features, hsp);
                // converty key2 to 2; because that's the image we need.
                hsp = hsp.substr(3); 
               
                var img = this.imgs[Std.parseInt(hsp) - 1];
                var xy0 = img.localToGlobal(new flash.geom.Point(coords[0],coords[1]));
                var xy1 = img.localToGlobal(new flash.geom.Point(coords[2],coords[3]));

                g.drawRect(xy0.x - 2, xy0.y - 2
                   , 1 + coords[2] - coords[0]
                   , 1 + coords[3] - coords[1]);

                if(pair.has_pair != 0){ 
                    
                    gcoords.push([Math.round(xy0.x),Math.round(xy0.y)
                                    ,Math.round(xy1.x),Math.round(xy1.y)]);
                }
                else { break; }
            }
            g.lineStyle(line_width, pair.color);
        }
        var j = 0;
        while(j<gcoords.length){
            var h0 = this.gcoords[j];
            var h1 = this.gcoords[j+1];
            g.moveTo( (h0[0] + h0[2])/2, (h0[1] + h0[3])/2);
            g.lineTo( (h1[0] + h1[2])/2, (h1[1] + h1[3])/2);
            j+=2;
        }

        // if it was showing all the hsps, dont show the annotation.
        if( this._all){
            rect.tf.htmlText = 'NOT SHOWING ANNOTATION FOR MULTIPLE HITS';
        }
        else{
            rect.show();
        }
    }


    public static function main(){
        haxe.Firebug.redirectTraces();
        flash.Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;
        flash.Lib.current.stage.align     = StageAlign.TOP_LEFT;
        flash.Lib.current.addChild( new Gobe());
    }


    public function new(){
        super();
        var p = flash.Lib.current.loaderInfo.parameters;
        trace(p);
        this.QUERY_URL = p.base_url + 'query.pl?';
        line_width = 1;
        this.base_url  = p.base_url;
        this.img = p.img;
        this.tmp_dir   = p.tmp_dir;
        this.n         = p.n;
        _heights = [];
        var i:Int;
        for(i in 0...p.n){ _heights[i] = 0; }
        getImageTitles(); // this calls initImages();
        loadStyles(p.base_url + '/static/gobe.css');
    }

    public function getImageTitles(){
        var ul = new URLLoader();
        ul.addEventListener(Event.COMPLETE, imageTitlesReturn);
        ul.load(new URLRequest(this.QUERY_URL + '&image_names=1&db='
          + this.tmp_dir +  '/' + this.img + '.sqlite'));
    }
    public function imageTitlesReturn(e:Event){
            trace(e.target.data);
            _image_titles = Json.decode(e.target.data);
            initImages();
    }
    public function initImages(){
        imgs = new Array<GImage>();
        var i:Int;
        for(i in 0...n){
            var url = this.tmp_dir + this.img + '_' + (i + 1) + '.png';
            imgs[i] = new GImage(url,i);
            imgs[i].addEventListener(GEvent.LOADED, imageLoaded);
        }
    }

    public function imageLoaded(e:Event){ 
        var i:Int = 0;
        var y:Int = 0;
        trace(this);
        _heights[e.target.i] = e.target.image.height;
        for(h in _heights){ if(h ==0){ return; } }
        // note, this depends on the images being loaded in order.
        // TODO: fix so it doesnt depend on order.
        
        for(h in _heights){
            var img = imgs[i];
            img.y = y;
            flash.Lib.current.addChildAt(img,0);
            var ttf = new TextField();
            ttf.text = _image_titles[i];
            ttf.alpha = 50;
            ttf.y = y ; ttf.opaqueBackground = 0xffffff;
            ttf.autoSize = flash.text.TextFieldAutoSize.LEFT;
            ttf.border = true; ttf.borderColor = 0xcccccc;
            ttf.x = 15;
            flash.Lib.current.addChildAt(ttf,1);
            img.addEventListener(MouseEvent.CLICK, onClick);
            y+=h;
            i++;
        }
    }

    private function loadStyles(style_path:String){
        var ul = new URLLoader();
        ul.addEventListener(Event.COMPLETE, stylesLoaded);
        ul.load(new URLRequest(style_path));

    }
    private function stylesLoaded(e:Event){
        var style = new StyleSheet();
        style.parseCSS(cast(e.target, URLLoader).data);
        rect = new QueryBox(style, this.base_url);
        rect.x =  1030;
        rect.show();

        rect.plus.addEventListener(MouseEvent.CLICK, plusClick);
        rect.minus.addEventListener(MouseEvent.CLICK, minusClick);
    }

    private function plusClick(e:MouseEvent){
            line_width += 1;
            rect.tf_size.htmlText = 'line width: <b>' + line_width + '</b>';
    }
    private function minusClick(e:MouseEvent){
        if( line_width > 0){
            line_width -= 1;
            rect.tf_size.htmlText = 'line width: <b>' + line_width + '</b>';
        }
    }
}

class GImage extends Sprite {

    private var _imageLoader:Loader;
    private var _bitmap:BitmapData;
    public  var image:Bitmap;
    public  var url:String;
    public  var i:Int;


    public function new(url:String,i:Int){
        super();
        this.url = url;
        this.i   = i;
        _imageLoader = new Loader();
        _imageLoader.load(new URLRequest(url));
        _imageLoader.contentLoaderInfo.addEventListener(Event.COMPLETE, onComplete);
    }

    private function onComplete(event:Event) {
        image = cast(_imageLoader.content, Bitmap);
        _bitmap = image.bitmapData;
        dispatchEvent(new GEvent(GEvent.LOADED));
        addChild(image);
    }

}


class GEvent extends Event {
    public static var LOADED = "LOADED";
    public function new(type:String){
        super(type);
    }
}

class QueryBox extends Sprite {
    private var _width:Int;
    private var _il:Loader;
    private var _ilplus:Loader;
    private var _ilminus:Loader;
    private var _height:Int;
    private var _taper:Int;
    private var _close:Sprite;
    

    public  var tf:TextField;
    public  var plus:Sprite;
    public  var tf_size:TextField;
    public  var minus:Sprite;

    public function show(){
        var g = this.graphics;
        g.lineStyle(1,0x777777);
        g.beginFill(0xcccccc);
        g.drawRoundRect(0,0,_width + 1,_height + 2 * _taper,_taper);
        g.endFill();
        this.addChild(tf);
        this.addChild(_close);
        this.addChild(plus);
        this.addChild(minus);
        this.addChild(tf_size);
    }

    public function hide(){
        this.removeChild(tf);
        this.removeChild(_close);
        this.removeChild(plus);
        this.removeChild(minus);
        this.removeChild(tf_size);
        this.graphics.clear();
    }

    public function new(style:StyleSheet, base_url:String){
        super();
        _width  = 360;
        _height = 630;
        _taper  = 20;

        addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent){
            if(Std.is(e.target,QueryBox)){ e.target.startDrag(); }
        });
        addEventListener(MouseEvent.MOUSE_UP, function(e:MouseEvent){
            if(Std.is(e.target,QueryBox)){ e.target.stopDrag(); }
        });


        tf = new TextField();
        tf.wordWrap   = true;
        tf.border     = false;
        tf.styleSheet = style;
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
        tf_size.width = 90;
        tf_size.height = 30;
        tf_size.htmlText = "line width: <b>1</b>";
        tf_size.x = _width - 165;
        tf_size.y = 0;



        var loader = new URLLoader();
        loader.addEventListener(Event.COMPLETE, handleHtmlLoaded);
        loader.load(new URLRequest(base_url + "docs/textfield.html"));
        _close = new Sprite();
        plus = new Sprite();
        minus = new Sprite();

        _close.addEventListener(MouseEvent.CLICK, function (e:MouseEvent){
            e.target.parent.hide();
        });


        _il = new Loader();
        _il.contentLoaderInfo.addEventListener(Event.COMPLETE, handleCloseLoaded);
        _il.load(new URLRequest(base_url + "static/close_button.gif"));

        
        _ilplus = new Loader();
        _ilplus.contentLoaderInfo.addEventListener(Event.COMPLETE, handlePlusLoaded);
        _ilplus.load(new URLRequest(base_url + "static/plus.gif"));



        _ilminus = new Loader();
        _ilminus.contentLoaderInfo.addEventListener(Event.COMPLETE, handleMinusLoaded);
        _ilminus.load(new URLRequest(base_url + "static/minus.gif"));

        flash.Lib.current.addChild(this);

    }
    private function handleCloseLoaded(e:Event){
        _close.addChild(cast(_il.content,Bitmap));
        _close.x = _width - 20;
        _close.y = 2.5;
    }
    private function handlePlusLoaded(e:Event){
        plus.addChild(cast(_ilplus.content,Bitmap));
        plus.x = _width - 35;
        plus.y = 2.5;
    }
    private function handleMinusLoaded(e:Event){
        minus.addChild(cast(_ilminus.content,Bitmap));
        minus.x = _width - 50;
        minus.y = 2.5;
    }
    public function handleHtmlLoaded(e:Event){
        tf.text = "'" + e.target.data + "'";
    }


}
