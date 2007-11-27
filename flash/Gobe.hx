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
    private var pad_gs:Int; // how many bp in to put the bars from the edge of the image
    private var img:String;
    private var tmp_dir:String;
    private var freezable:Bool; // does the user have permission to freeze this genespace?
    private var genespace_id:Int; // the id to link the cns's when freezing
    private var bpmins:Array<Int>; //the left most bp of the image
    private var bpmaxs:Array<Int>; //the left most bp of the image

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
    private var _extents:Array<Hash<Float>>;


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
        var idx:Int = e.target.i + 1;
        var url = this.QUERY_URL + '&y=' + e.localY + '&img=' + idx + '&db=' + sqlite;

        var removed = false;
        if(! e.shiftKey){
            var r:GRect; var i:Int = 0;
            for(r in _rectangles){
               // removed the rectangle (and pair) that was clicked on.
               if(r.hitTestPoint(e.stageX, e.stageY)){
                    var pair_idx = i % 2 == 0 ? i : i - 1;
                    var rects = _rectangles.splice(pair_idx, 2);
                    flash.Lib.current.removeChild(rects[1]);
                    flash.Lib.current.removeChild(rects[0]);
                    // one line per 2 rectangles.
                    var lidx = Math.floor(i/2);
                    flash.Lib.current.removeChild(_lines.splice(lidx, 1)[0]);
                    removed = true;
                    i--;
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
        gcoords = new Array<Array<Int>>();
        var pair:Hash<Dynamic>;

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
                var db_id = coords[4]; // this links to the id in the image_data table
               
                var img = this.imgs[Std.parseInt(hsp) - 1];
                var xy0 = img.localToGlobal(new flash.geom.Point(coords[0],coords[1]));
                var xy1 = img.localToGlobal(new flash.geom.Point(coords[2],coords[3]));

                var x0 = xy0.x;
                var y0 = xy0.y;
                var w = coords[2] - coords[0];
                var h = coords[3] - coords[1];
                var pr:GRect;
                // dont add a rectangle that's already drawn
                var seen = false;
                for(pr in _rectangles){
                    seen = x0 == pr.x0 && y0 == pr.y0 && w == pr.w; // && h == pr.h;
                    if(seen){break;}
                }
                if (! seen) {     
                    var r = new GRect(x0, y0 , w, h);
                    flash.Lib.current.addChild(r);
                    _rectangles.push(r);
                    gcoords.push([ Math.round(xy0.x)
                                 , Math.round(xy0.y)
                                 , Math.round(xy1.x)
                                 , Math.round(xy1.y)
                                 , db_id
                        ]);
                }

            }
            lcolor = pair.color;
        }


        // draw lines between hsps.
        var j = 0;
        while(j<gcoords.length){
            var h0 = gcoords[j];
            var h1 = gcoords[j+1];
            var db_id0 = h0[4];
            var db_id1 = h1[4];
            j+=2;
            var l = new GLine(
                        (h0[0] + h0[2])/2
                        , (h0[1] + h0[3])/2
                        , (h1[0] + h1[2])/2
                        , (h1[1] + h1[3])/2
                        , line_width
                        , lcolor
                        , db_id0
                        , db_id1
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

        this.QUERY_URL = p.base_url + 'query.pl?';
        line_width     = 1;
        this.base_url  = p.base_url;
        this.img       = p.img;
        this.tmp_dir   = p.tmp_dir;
        this.pad_gs  = p.pad_gs;
        this.n         = p.n;

        this.genespace_id = Std.parseInt(p.gsid);
        this.freezable = p.freezable == 'false' ? false : (this.genespace_id == 0) ? false : true;

        _heights = [];
        var i:Int;
        for(i in 0...p.n){ _heights[i] = 0; }
        getImageInfo(); // this calls initImages();

        rect = new QueryBox(this.base_url, freezable);
        rect.x =  1030;
        rect.show();
        _rectangles = [];
        _lines      = [];
        _extents    = [];

        rect.plus.addEventListener(MouseEvent.CLICK, plusClick);
        rect.minus.addEventListener(MouseEvent.CLICK, minusClick);
        rect.clear_sprite.addEventListener(MouseEvent.CLICK, clearGraphics);
        if(freezable){
            rect.freeze.addEventListener(MouseEvent.CLICK, freezeSpace);
        }
    }

    public function freezeSpace(e:MouseEvent){
        var gl: GLine;
        var ids = new Array<Int>();
        for(gl in _lines){
            ids.push(gl.db_id1);
            ids.push(gl.db_id2);
        }
        var ul = new URLLoader();    
        ul.addEventListener(Event.COMPLETE, function(e:Event){
            var str:String = e.target.data;
            ExternalInterface.call('alert', str);
        });
        ul.load(new URLRequest(this.QUERY_URL +  '&db=' + this.tmp_dir + '/' + this.img + '.sqlite' 
                                                + '&save_cns=' + ids.join(",")
                                                + '&gsid=' + this.genespace_id
                                                ));
    }

    public function getImageInfo(){
        var ul = new URLLoader();
        ul.addEventListener(Event.COMPLETE, imageInfoReturn);
        ul.load(new URLRequest(this.QUERY_URL + '&get_info=1&db='
          + this.tmp_dir +  '/' + this.img + '.sqlite'));
    }
    public function imageInfoReturn(e:Event){
            var strdata:String = e.target.data;
            this.bpmins = [];
            this.bpmaxs = [];
            trace(strdata);
            var json = Json.decode(strdata);
            _image_titles = json.titles;
            json.extents[0];// let the compiler know it's an array
            json.anchors[0];// let the compiler know it's an array

            var i = 0;
            for(exts in json.extents){
                _extents[i] = new Hash<Float>();
                _extents[i].set('bpmin', exts.bpmin);
                _extents[i].set('bpmax', exts.bpmax);
                _extents[i].set('img_width', exts.img_width);
                // base pairs per pixel.
                _extents[i].set('bpp', (exts.bpmax - exts.bpmin)/exts.img_width);
                this.bpmins[i] = Math.round(exts.bpmin);
                this.bpmaxs[i] = Math.round(exts.bpmax);
                ++i;
            }   

            i = 0;
            for(exts in json.anchors){
                _extents[i].set('xmin', exts.xmin);
                _extents[i].set('xmax', exts.xmax);
                _extents[i].set('idx', exts.idx);
                ++i;
            }
            trace(_extents);
            
            initImages();
    }

    public function pix2rw(px:Float, i:Int):Float {
        return px * _extents[i].get('bpp');
    }
    public function rw2pix(rw:Float, i:Int):Float {
        return (rw - _extents[i].get('bpmin')) / _extents[i].get('bpp');
    }

    // find the up or down stream basepairs given a mouse click
    // (actually the e.globalX fo the mouseclick).
    // it determines whether to use up/downstream based on which side
    // of the anchor the click falls on.
    public function pix2relative(px:Float, i:Int):Float{
        var ext = _extents[i];
        var click_bp =  px * ext.get('bpp');
        if(px > ext.get('xmin') && px  < ext.get('xmax')){
            return 1;
        }
        if(px < ext.get('xmin')) {
            var end_of_anchor_bp = ext.get('xmin') * ext.get('bpp');
            return end_of_anchor_bp - click_bp;
        }
        var end_of_anchor_bp = ext.get('xmax') * ext.get('bpp');

        return ( click_bp - end_of_anchor_bp);
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
            if(ttf.text.indexOf('Reverse Complement') != -1  ) {
                ttf.textColor = 0xff0000;
            }
            ttf.borderColor      = 0xcccccc;
            ttf.opaqueBackground = 0xf4f4f4;
            ttf.autoSize         = flash.text.TextFieldAutoSize.LEFT;

            flash.Lib.current.addChildAt(ttf, 1);
            img.addEventListener(MouseEvent.CLICK, onClick);
            i++;
             
            var xmin = rw2pix(this.bpmins[i - 1] + this.pad_gs, i - 1);
            var gs0 = new GSlider(1 , y + 28, h - 35,'drup' + i, 0, _extents[i-1].get('xmin') - 4);
            gs0.i = 1;
            // make sure pad_gs cant cause the min to go beyond the gene
            gs0.x = xmin < 1 ? 1: (xmin > _extents[i-1].get('xmin') ?  _extents[i-1].get('xmin') : xmin);
            trace(xmin + ", " + gs0.x);
            flash.Lib.current.addChild(gs0);
            gs0.addEventListener(MouseEvent.MOUSE_UP, sliderMouseUp);
            gs0.addEventListener(MouseEvent.MOUSE_OUT, sliderMouseOut);
            var xmax = rw2pix(this.bpmaxs[i-1] - this.pad_gs, i - 1);
            var gs1 = new GSlider(1, y + 28, h - 35,'drdown' + i, _extents[i-1].get('xmax') + 4 ,_extents[i-1].get('img_width'));
            // fix in case the pad_gs causes the max to go below the  xmax
            gs1.x = xmax > _extents[i-1].get('img_width') ?  _extents[i-1].get('img_width') : (xmax < _extents[i-1].get('xmax') ? _extents[i-1].get('xmax') : xmax); 
            trace(xmax + ", " + gs1.x);
            gs1.i = i - 1;
            gs1.addEventListener(MouseEvent.MOUSE_UP, sliderMouseUp);
            gs1.addEventListener(MouseEvent.MOUSE_OUT, sliderMouseOut);
            flash.Lib.current.addChild(gs1);


            y+=h;
        }
    }
    // this is a hack for when a mouseup occurs off the slider. this
    // seems to work ok. to trigger intuitive behavior.
    public function sliderMouseOut (e:MouseEvent){
        if(Math.abs(e.target.lastX - e.stageX ) > 15){ sliderMouseUp(e);}
    }

    public function sliderMouseUp(e:MouseEvent){
            e.target.stopDrag();
            var xupdown = Math.round(pix2relative(e.stageX, e.target.i));
            ExternalInterface.call('set_genespace',e.target.id,xupdown);
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
        this.h  = h;
        var g = this.graphics;
        g.lineStyle(2,0x00000);
        g.drawRect(x, y, w, h);
    }
}

class GLine extends Shape {
    public var db_id1:Int;
    public var db_id2:Int;

    public function new(x0:Float, y0:Float, x1:Float, y1:Float, lwidth:Int, lcolor:Int, db_id1, db_id2) {
        super();
        var g = this.graphics;    
        g.lineStyle(lwidth, lcolor);
        g.moveTo(x0,y0);
        g.lineTo(x1,y1);
        this.db_id1 = db_id1;
        this.db_id2 = db_id2;
    }
}

class GSlider extends Sprite {
    // id is the string (drup1,drdown1, drup2, or drdown2)
    public var id:String;
    public var bounds:Rectangle;
    public var lastX:Float;
    public var i:Int; // the index of the image it's on
    public var gobe:Gobe;
    public function new(x0:Float, y0:Float, h:Float, id:String, bounds_min:Float, bounds_max:Float) {
        super();
        this.id = id;
        var g = this.graphics;
        // TODO: can make these bounds based on the _extents stuff.
        bounds = new Rectangle(bounds_min,0,bounds_max,0);
        g.beginFill(0xffcccccc);
        g.lineStyle(1,0x000000);
        g.drawRect(x0, y0, 7, h);
        g.endFill();
        var self = this;
        addEventListener(MouseEvent.MOUSE_DOWN, sliderMouseDown);    
        addEventListener(MouseEvent.MOUSE_MOVE, sliderMouseMove);

        // the mouse up is in the Gobe namespace as we need to access
        // pix2relative.
    }

    public function sliderMouseMove (e:MouseEvent){
        lastX = e.stageX;
    }
    public function sliderMouseDown(e:MouseEvent){
            e.target.startDrag(false, bounds);
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
    private var _if:Loader;
    private var _close:Sprite;
    

    public  var freeze:Sprite;
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
        this.addChild(freeze);
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
        this.removeChild(freeze);
        this.removeChild(minus);
        this.removeChild(clear_sprite);
        this.removeChild(tf_size);
        this.graphics.clear();
    }

    public function new(base_url:String, freezable:Bool){
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
        freeze = new Sprite();
        plus = new Sprite();
        minus = new Sprite();
        clear_sprite = new Sprite();

        _close.addEventListener(MouseEvent.CLICK, function (e:MouseEvent){
            e.target.parent.hide();
        });

        if(freezable){
            _if = new Loader();
            _if.contentLoaderInfo.addEventListener(Event.COMPLETE, handleFreezeLoaded);
            _if.load(new URLRequest(base_url + "static/save.gif"));
        }
            


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

    private function handleFreezeLoaded(e:Event){
        freeze.addChild(cast(_if.content,Bitmap));
        freeze.x = 90;
        freeze.y = 1;

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

