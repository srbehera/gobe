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

    // base_url and n are sent in on the url.
    private var base_url:String;
    private var n:Int;
    private var img:String;
    private var tmp_dir:String;

    private var _heights:Array<Int>;

    private var rect:QueryBox;
    private var _all:Bool;
    private var imgs:Array<GImage>;
    private var gcoords:Array<Array<Float>>;
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
                      + img.substr(0,img.lastIndexOf('.png') - 2) + '.sqlite';
        

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
        this.gcoords = [];
        var pair:Hash<Dynamic>;
        // TODO: create another page in front of hte images for the
        // hsp outlines and use an object for each rectangle so it
        // can respond to mouseover events.
        var g = flash.Lib.current.graphics;
        
        var isGene = false;
        for(pair in json){
            g.lineStyle(2);
            rect.tf.htmlText = "<font color='#0000ff'><u><a target='_blank' href='" + pair.link + "'>full annotation</a></u></font>&#10;&#10;";
            rect.tf.htmlText += pair.annotation;
            
            for(hsp in Reflect.fields(pair.features)){
                trace(hsp);
                 
                if(hsp == '' || hsp == 'key'){ isGene = true; continue; }
                var coords:Array<Dynamic> = Reflect.field(pair.features, hsp);
                // converty key2 to 2; because that's the image we need.
                hsp = hsp.substr(3); 
               
                var img = this.imgs[Std.parseInt(hsp) -1];
                var xy0 = img.localToGlobal(new flash.geom.Point(coords[0],coords[1]));
                var xy1 = img.localToGlobal(new flash.geom.Point(coords[2],coords[3]));
                this.gcoords.push([xy0.x,xy0.y,xy1.x,xy1.y]);
                g.drawRect(xy0.x - 2, xy0.y - 2
                   , 1 + coords[2] - coords[0]
                   , 1 + coords[3] - coords[1]);
            }
            g.lineStyle(0, pair.color);
        }
        var j = 0;
        while(j<this.gcoords.length && ! isGene ){
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


    static function main(){
        haxe.Firebug.redirectTraces();
        var p = flash.Lib.current.loaderInfo.parameters;
        flash.Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;
        flash.Lib.current.stage.align     = StageAlign.TOP_LEFT;


        flash.Lib.current.addChild(
            new Gobe(p.base_url, p.img, p.tmp_dir, p.n)
        );
    }


    public function new(base_url:String, img:String, tmp_dir, n:Int){
        super();
        this.QUERY_URL = base_url + 'query.pl?';
        this.base_url  = base_url;
        this.img = img;
        this.tmp_dir   = tmp_dir;
        this.n         = n;
        _heights = [];
        var i:Int;
        for(i in 0...n){ _heights[i] = 0; }
        getImageTitles(); // this calls initImages();
        loadStyles(base_url + '/static/gobe.css');
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
        /*
        while(i < imgs.length){
            var img = imgs[i];
            if (img == e.target){ break; }
            y += e.target.image.height;
            i++;
        }
        flash.Lib.current.addChildAt(imgs[i],0);
        imgs[i].y = y;
        var ttf = new TextField();
        ttf.text = _image_titles[i];
        ttf.alpha = 50;
        ttf.y = y ; ttf.opaqueBackground = 0xffffff;
        ttf.autoSize = flash.text.TextFieldAutoSize.LEFT;
        ttf.border = true; ttf.borderColor = 0xcccccc;
        ttf.x = 15;
        flash.Lib.current.addChildAt(ttf,1);
        imgs[i].addEventListener(MouseEvent.CLICK, onClick);
        */
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
    private var _height:Int;
    private var _taper:Int;
    private var _close:Sprite;
    public  var tf:TextField;

    public function show(){
        var g = this.graphics;
        g.lineStyle(1,0x777777);
        g.beginFill(0xcccccc);
        g.drawRoundRect(0,0,_width + 1,_height + 2 * _taper,_taper);
        g.endFill();
        this.addChild(tf);
        this.addChild(_close);
    }

    public function hide(){
        this.removeChild(tf);
        this.removeChild(_close);
        this.graphics.clear();
    }

    public function new(style:StyleSheet, base_url:String){
        super();
        _width  = 360;
        _height = 630;
        _taper  = 20;

        addEventListener(MouseEvent.MOUSE_DOWN, function(e:MouseEvent){
            if(Std.is(e.target,Sprite)){ e.target.startDrag(); }
        });
        addEventListener(MouseEvent.MOUSE_UP, function(e:MouseEvent){
            if(Std.is(e.target,Sprite)){ e.target.stopDrag(); }
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

        var loader = new URLLoader();
        loader.addEventListener(Event.COMPLETE, handleHtmlLoaded);
        loader.load(new URLRequest(base_url + "docs/textfield.html"));
        _close = new Sprite();
        _close.addEventListener(MouseEvent.CLICK, function (e:MouseEvent){
            e.target.parent.hide();
        });

        _il = new Loader();
        _il.contentLoaderInfo.addEventListener(Event.COMPLETE, handleCloseLoaded);
        _il.load(new URLRequest(base_url + "static/close_button.gif"));
        flash.Lib.current.addChild(this);
    }
    private function handleCloseLoaded(e:Event){
        _close.addChild(cast(_il.content,Bitmap));
        _close.x = _width - 20;
        _close.y = 2.5;
    }

    public function handleHtmlLoaded(e:Event){
        tf.text = "'" + e.target.data + "'";
    }


}
