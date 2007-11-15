import flash.external.ExternalInterface; 
import flash.display.MovieClip;
import flash.display.Sprite;
import flash.display.Shape;
import flash.display.Loader;
import flash.display.StageScaleMode;
import flash.display.StageAlign;
import flash.display.Bitmap;
import flash.display.BitmapData;
import flash.events.Event;
import flash.events.KeyboardEvent;
import flash.events.MouseEvent;
import flash.events.TimerEvent;
import flash.geom.Point;
import flash.geom.Rectangle;
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
    // hold the hsps so we know if one contained a click
    public var _rectangles:Array<GRect>; 
    public var _lines:Array<GLine>; 

    private var _all:Bool;
    private var imgs:Array<GImage>;
    private var gcoords:Array<Array<Int>>;
    private var QUERY_URL:String;
    private var _image_titles:Array<String>;


    public function onClick(e:MouseEvent) {
        // only send the query to the server if they clicked on a
        // colored pixel or they hit the shift key.
        if(e.shiftKey || e.target._bitmap.getPixel(e.localX, e.localY)){
            query(e);
        }
    }
    public function clearGraphics(e:MouseEvent){
        var r:GRect; 
        for(r in _rectangles){
            flash.Lib.current.removeChild(r);
        }
        var l:GLine; 
        for(l in _lines){
            flash.Lib.current.removeChild(l);
        }
        _rectangles = [];
        _lines = [];
    }
    private function query(e:MouseEvent){
        var img = e.target.url;
        var sqlite = img.substr(0, img.lastIndexOf('_')) + '.sqlite';
        var url = this.QUERY_URL + '&y=' + e.localY + '&img=' + img + '&db=' + sqlite;

        var removed = false;
        if(! e.shiftKey){
            var r:GRect; var i:Int = 0;
            for(r in _rectangles){
               if(r.hitTestPoint(e.stageX, e.stageY)){
                    var pair_idx = i % 2 == 0 ? i : i - 1;
                    var rects = _rectangles.splice(pair_idx, 2);
                    trace(Reflect.fields(rects[0]));
                    flash.Lib.current.removeChild(rects[1]);
                    flash.Lib.current.removeChild(rects[0]);
                    // one line per 2 rectangles.
                    var lidx = Math.floor(i/2);
                    flash.Lib.current.removeChild(_lines.splice(lidx, 1)[0]);
                    removed = true;
               } else { i++;  }
            }
            if(removed) { return; }
            rect.tf.text = '';
            url += '&x=' + e.localX;
            this._all = false;
        } 
        else {
            url      += '&all=1';
            this._all = true;
        }

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
        var lcolor:Int;
        
        for(pair in json){
            g.lineStyle(line_width);
            rect.tf.htmlText = "<font color='#0000ff'><u><a target='_blank' href='" + pair.link + "'>full annotation</a></u></font>&#10;&#10;";
            rect.tf.htmlText += pair.annotation;
            if(! pair.has_pair){ continue; }
            for(hsp in Reflect.fields(pair.features)){
                 
                var coords:Array<Dynamic> = Reflect.field(pair.features, hsp);
                // converty key2 to 2; because that's the image we need.
                hsp = hsp.substr(3); 
               
                var img = this.imgs[Std.parseInt(hsp) - 1];
                var xy0 = img.localToGlobal(new flash.geom.Point(coords[0],coords[1]));
                var xy1 = img.localToGlobal(new flash.geom.Point(coords[2],coords[3]));

                var x0 = xy0.x - 1;
                var y0 = xy0.y - 1;
                var w = 1 + coords[2] - coords[0];
                var h = 1 + coords[3] - coords[1];

                var pr:GRect;
                // dont add a rectangle that's already drawn
                var seen = false;
                for(pr in _rectangles){
                    seen = x0 == pr.x0 && y0 == pr.y0 && w == pr.w && h == pr.h;
                    if(seen){break;}
                }
                if (! seen) {     
                    var r = new GRect(x0, y0 , w, h);
                    flash.Lib.current.addChild(r);
                    _rectangles.push(r);
                    gcoords.push([Math.round(xy0.x),Math.round(xy0.y)
                                 ,Math.round(xy1.x),Math.round(xy1.y)]);
                }

            }
            lcolor = pair.color;
        }


        // draw lines between hsps.
        var j = 0;
        while(j<gcoords.length){
            var h0 = gcoords[j];
            var h1 = gcoords[j+1];
            //g.moveTo( (h0[0] + h0[2])/2, (h0[1] + h0[3])/2);
            //g.lineTo( (h1[0] + h1[2])/2, (h1[1] + h1[3])/2);
            j+=2;
            var l = new GLine(
                  (h0[0] + h0[2])/2
                , (h0[1] + h0[3])/2
                , (h1[0] + h1[2])/2
                , (h1[1] + h1[3])/2
                , line_width
                , lcolor
                );
            _lines.push(l);
            flash.Lib.current.addChild(l);
        }

        // if it was showing all the hsps, dont show the annotation.
        if( this._all){
            rect.tf.htmlText = '<b>Not showing annotation for multiple hits.</b>';
            return;
        }
        rect.show();
    }


    public static function main(){
        haxe.Firebug.redirectTraces();
        flash.Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;
        flash.Lib.current.stage.align     = StageAlign.TOP_LEFT;
        flash.Lib.current.addChild( new Gobe());
    }



    public function new(){
        super();
        //ExternalInterface.call('alert','hiiii');
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

        rect = new QueryBox(this.base_url);
        rect.x =  1030;
        rect.show();
        _rectangles = [];
        _lines      = [];

        rect.plus.addEventListener(MouseEvent.CLICK, plusClick);
        rect.minus.addEventListener(MouseEvent.CLICK, minusClick);
        rect.clear_sprite.addEventListener(MouseEvent.CLICK, clearGraphics);
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

        _heights[e.target.i] = e.target.image.height;
        // wait for all previous images to load...
        for(h in _heights){ if(h == 0){ return; } }
        
        for(h in _heights){
            var img = imgs[i];
            img.y = y;
            flash.Lib.current.addChildAt(img, 0);

            var ttf = new TextField();
            ttf.text   = _image_titles[i];
            ttf.y      = y ; 
            ttf.x      = 15;
            ttf.border = true; 
            ttf.borderColor      = 0xcccccc;
            ttf.opaqueBackground = 0xf4f4f4;
            ttf.autoSize         = flash.text.TextFieldAutoSize.LEFT;

            flash.Lib.current.addChildAt(ttf, 1);
            img.addEventListener(MouseEvent.CLICK, onClick);
            i++;
            flash.Lib.current.addChild(new GSlider(1, y + 20, h - 40,'drup' + i));
            flash.Lib.current.addChild(new GSlider(595, y + 20, h - 40,'drdown' + i));
            y+=h;
        }
    }


    private function plusClick(e:MouseEvent){
        line_width += 1;
        rect.tf_size.htmlText = 'line width: <b>' + line_width + '</b>';
    }
    private function minusClick(e:MouseEvent){
        if( line_width < 1){ return; }
        line_width -= 1;
        rect.tf_size.htmlText = 'line width: <b>' + line_width + '</b>';
    }
}

// instead of just drawing on the stage, we add a lightweight shape.
class GRect extends Shape {
    public var x0:Float;
    public var y0:Float;
    public var w:Float;
    public var h:Float;

    public function new(x:Float, y:Float, w:Float, h:Float) {
        super();
        this.x0 = x;
        this.y0 = y;
        this.w  = w;
        this.w  = h;
        var g = this.graphics;
        g.lineStyle(2,0x00000);
        g.drawRect(x, y, w, h);
    }
}

class GLine extends Shape {
    public function new(x0:Float, y0:Float, x1:Float, y1:Float, lwidth:Int, lcolor:Int) {
        super();
        var g = this.graphics;    
        g.lineStyle(lwidth, lcolor);
        g.moveTo(x0,y0);
        g.lineTo(x1,y1);
    }
}

class GSlider extends Sprite {
    // id is the string (drup1,drdown1, drup2, or drdown2)
    public var id:String;
    public var bounds:Rectangle;
    public function new(x0:Float, y0:Float, h:Float, id:String) {
        super();
        this.id = id;
        var g = this.graphics;
        g.beginFill(0xcccccc);
        g.lineStyle(1,0x000000);
        g.drawRect(x0, y0, 7, h);
        g.endFill();
        var self = this;
        addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent){
            var bounds = new Rectangle(0,0,1000,0);
            self.startDrag(false,bounds);
            trace(bounds);
        });
        addEventListener(MouseEvent.MOUSE_UP, function(e:MouseEvent){
            self.stopDrag();
            ExternalInterface.call('set_genespace',self.id,self.x);
        });    
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
    private var _ilclear:Loader;
    private var _height:Int;
    private var _taper:Int;
    private var _close:Sprite;
    

    public  var tf:TextField;
    public  var plus:Sprite;
    public  var clear_sprite:Sprite;
    public  var tf_size:TextField;
    public  var minus:Sprite;

    public function show(){
        var g = this.graphics;
        g.lineStyle(1,0x777777);
        g.beginFill(0xcccccc);
        g.drawRoundRect(0, 0, _width + 1, _height + 2 * _taper, _taper);
        g.endFill();
        this.addChild(tf);
        this.addChild(_close);
        this.addChild(plus);
        this.addChild(clear_sprite);
        this.addChild(minus);
        this.addChild(tf_size);
    }

    public function hide(){
        this.removeChild(tf);
        this.removeChild(_close);
        this.removeChild(plus);
        this.removeChild(minus);
        this.removeChild(clear_sprite);
        this.removeChild(tf_size);
        this.graphics.clear();
    }

    public function new(base_url:String){
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
        tf.styleSheet = new StyleSheet();
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
        tf_size.width      = 90;
        tf_size.height     = 30;
        tf_size.htmlText   = "line width: <b>1</b>";
        tf_size.x          = _width - 165;
        tf_size.y          = 0;


        var loader = new URLLoader();
        loader.addEventListener(Event.COMPLETE, handleHtmlLoaded);
        loader.load(new URLRequest(base_url + "docs/textfield.html"));
        _close = new Sprite();
        plus = new Sprite();
        minus = new Sprite();
        clear_sprite = new Sprite();

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

