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
    //private var line_width:Int;

    // base_url and n are sent in on the url.
    private var base_url:String;
    private var n:Int;
    private var pad_gs:Int; // how many bp in to put the bars from the edge of the image
    private var img:String;
    private var tmp_dir:String;
    public var db:String; // path to database
    private var freezable:Bool; // does the user have permission to freeze this genespace?
    public var genespace_id:Int; // the id to link the cns's when freezing

    private var _heights:Array<Int>;

    public var qbx:QueryBox;
    // hold the hsps so we know if one contained a click
    public var _rectangles:Array<GRect>; 
    public var _lines:Array<GLine>; 
    public var panel:Sprite; // holds the lines.

    private var _all:Bool;
    public var imgs:Array<GImage>;
    public var image_info:Hash<Dynamic>;
    private var gcoords:Array<Array<Int>>;
    private var QUERY_URL:String;
    public var image_titles:Array<String>;


    public function onClick(e:MouseEvent) {
        // only send the query to the server if they clicked on a
        // colored pixel or they hit the shift key.
        query(e);
    }
    public function clearPanelGraphics(e:MouseEvent){
        while(panel.numChildren != 0){ panel.removeChildAt(0); }
        _rectangles = [];
        _lines = [];
    }
    private function query(e:MouseEvent){
        var img = e.target.url;
        var sqlite = img.substr(0, img.lastIndexOf('_')) + '.sqlite';
        var idx:Int = image_info.get(image_titles[e.target.i]).get('anchors').get('idx');
        var url = this.QUERY_URL + '&y=' + e.localY + '&img=' + idx + '&db=' + sqlite;

        var removed = false;
        if(! e.shiftKey){
            var r:GRect; var i:Int = 0;
            for(r in _rectangles){
               // removed the rectangle (and pair) that was clicked on.
               if(r.hitTestPoint(e.stageX, e.stageY)){
                    var pair_idx = i % 2 == 0 ? i : i - 1;
                    var rects = _rectangles.splice(pair_idx, 2);
                    panel.removeChild(rects[1]);
                    panel.removeChild(rects[0]);
                    // one line per 2 rectangles.
                    var lidx = Math.floor(i/2);
                    panel.removeChild(_lines.splice(lidx, 1)[0]);
                    removed = true;
                    i--;
               } else { i++;  }
            }
            if(removed) { return; }
            qbx.info.text = '';
            url += '&x=' + e.localX;
            this._all = false;
        } 
        else {
            url      += '&all=1';
            this._all = true;
        }
        trace(url);
        var queryLoader = new URLLoader();
        queryLoader.addEventListener(Event.COMPLETE, handleQueryReturn);
        queryLoader.load(new URLRequest(url));
    }

    public function drawHsp(coords:Array<Int>, img_idx:Int){
        var img:GImage = imgs[img_idx];
        var xy0 = img.localToGlobal(new flash.geom.Point(coords[0],coords[1]));
        var xy1 = img.localToGlobal(new flash.geom.Point(coords[2],coords[3]));

        var db_id = coords[4]; // this links to the id in the image_data table
        var x0 = xy0.x;
        var y0 = xy0.y;
        var w = coords[2] - coords[0];
        var h = coords[3] - coords[1];
        var pr:GRect;
        // dont add a rectangle that's already drawn
        var r = new GRect(x0, y0 , w, h);
        if(panel.contains(r)){ return; }
        panel.addChild(r);
        _rectangles.push(r);
        gcoords.push([ Math.round(xy0.x)
                        , Math.round(xy0.y)
                        , Math.round(xy1.x)
                        , Math.round(xy1.y)
                        , db_id
            ]);

    }

    public function drawLines(?lcolor:Int){
        // draw lines between hsps.
        if(lcolor == null){ lcolor = 0xFF6464; }
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
                        , qbx.line_width
                        , lcolor
                        , db_id0
                        , db_id1
                    );
            if(!panel.contains(l)){
                panel.addChild(l);
                _lines.push(l);
            }
        }
    }

    private function handleQueryReturn(e:Event){
        var json:Array<Dynamic> = Json.decode(e.target.data).resultset;
        gcoords = new Array<Array<Int>>();
        var pair:Hash<Dynamic>;

        var lcolor:Int;
        for(pair in json){
            qbx.info.htmlText = "<p><a target='_blank' href='" + pair.link + "'>full annotation</a></p>&#10;&#10;";
            qbx.info.htmlText += "<p>" + pair.annotation + "</p>";
            if(! pair.has_pair){ continue; }

            var idx:Int = 0;
            for(hsp in Reflect.fields(pair.features)){
                var coords:Array<Int> = Reflect.field(pair.features, hsp);
                // converty key2 to 2; because that's the image we need. cant use '1' as a key because of
                // haxe bug.
                hsp = hsp.substr(3); 
                var img_idx = Std.parseInt(hsp) - 1;
                drawHsp(coords, img_idx);
            }
            lcolor = pair.color;
        }
        drawLines(lcolor);
        // if it was showing all the hsps, dont show the annotation.
        if( this._all){
            qbx.info.htmlText = '<b>Not showing annotation for multiple hits.</b>';
            return;
        }
        qbx.show();
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

        gcoords = new Array<Array<Int>>();

        this.QUERY_URL = p.base_url + 'query.pl?';
        this.base_url  = p.base_url;
        this.img       = p.img;
        this.tmp_dir   = p.tmp_dir;
        this.pad_gs  = p.pad_gs;
        this.n         = p.n;
        this.db = this.tmp_dir + '/' + this.img + '.sqlite';

        this.genespace_id = Std.parseInt(p.gsid);
        this.freezable = p.freezable == 'false' ? false : (this.genespace_id == 0) ? false : true;

        panel = new Sprite(); 
        addChild(panel);
        _heights = [];
        var i:Int;
        for(i in 0...p.n){ _heights[i] = 0; }
        getImageInfo(); // this calls initImages();
        qbx = new QueryBox(this.base_url, freezable, this);
        qbx.x =  1030;
        qbx.show();
        _rectangles = [];
        _lines      = [];

        qbx.clear_sprite.addEventListener(MouseEvent.CLICK, clearPanelGraphics);
        if(freezable){
            ExternalInterface.call('setheight');
        }
    }

    public function getImageInfo(){
        var ul = new URLLoader();
        ul.addEventListener(Event.COMPLETE, imageInfoReturn);
        ul.load(new URLRequest(this.QUERY_URL + '&get_info=1&db='
          + this.tmp_dir +  '/' + this.img + '.sqlite'));
    }
    public function imageInfoReturn(e:Event){
            var strdata:String = e.target.data;
            image_info = new Hash<Dynamic>();
            var json = Json.decode(strdata);
            // CONVERT THE JSON data into a HASH: sigh.
            image_titles = ['a','b'];
            for( title in Reflect.fields(json)){
                var info = Reflect.field(json, title);
                image_info.set(title, new Hash<Hash<Int>>());
                for (group_key in Reflect.fields(info)){
                    var group:Dynamic = Reflect.field(info, group_key);
                    if(group_key == 'i' || group_key == 'title'){
                        image_info.get(title).set(group_key, group);
                        if(group_key == 'i'){
                            image_titles[group] = title;
                        }
                        continue;
                    }
                    image_info.get(title).set(group_key, new Hash<Int>());
                    for(sub_group_key in Reflect.fields(group)){
                        image_info.get(title).get(group_key).set(sub_group_key, Reflect.field(group, sub_group_key));
                    }
                }
            }
            for(t in image_titles){
                var ext = image_info.get(t).get('extents');
                ext.set('bpp', (ext.get('bpmax') - ext.get('bpmin') + 1)/ext.get('img_width'));
            }
            trace(image_info);
            initImages();
    }

    public function pix2rw(px:Float, i:Int):Int {
        var exts = image_info.get(image_titles[i]).get('extents');
        trace(exts);
        return Math.round(exts.get('bpmin') + px * exts.get('bpp'));
    }
    public function rw2pix(rw:Float, i:Int):Float {
        var exts = image_info.get(imgs[i].title).get('extents');
        trace(exts);
        return (rw - exts.get('bpmin')) / exts.get('bpp');
    }

    // find the up or down stream basepairs given a mouse click
    // (actually the e.globalX fo the mouseclick).
    // it determines whether to use up/downstream based on which side
    // of the anchor the click falls on.
    public function pix2relative(px:Float, i:Int, updown:Int):Float{
        var ext:Hash<Int> = image_info.get(image_titles[i]).get('extents');
        var anchor:Hash<Int> = image_info.get(image_titles[i]).get('anchors');
        var click_bp =  px * ext.get('bpp');
        if(updown == -1) {
            var end_of_anchor_bp = anchor.get('xmin') * ext.get('bpp');
            return end_of_anchor_bp - click_bp;
        }
        return  click_bp - anchor.get('xmax') * ext.get('bpp');
    }

    public function initImages(){
        imgs = new Array<GImage>();
        for(k in 0...n){
            var title:String = image_titles[k];
            imgs[k] = new GImage(title, this.tmp_dir + title, k);
            imgs[k].addEventListener(GEvent.LOADED, imageLoaded);
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
            ttf.text   = image_info.get(image_titles[i]).get('title');
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
            // TODO move this onto the Rectangles.
            img.addEventListener(MouseEvent.CLICK, onClick);
            i++;
            add_sliders(img, i, y, h);
             
            img.addEventListener(MouseEvent.MOUSE_UP, imageMouseUp);
            //img.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP));
            y+=h;
        }
        if(freezable){
           qbx.anno.python_load(genespace_id);
        }
    }
    public function imageMouseUp(e:MouseEvent){ 
        var i:Int;
        for( i in 0 ... 2){
            e.target.sliders[i]._buttonDown = true;
            e.target.sliders[i].dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP));
        }
    }
    public function get_slider_locs_rw(i:Int){
        var img = imgs[i];
        var rw0 = pix2rw(img.sliders[0].x, i);
        var rw1 = pix2rw(img.sliders[1].x, i);
        return [rw0, rw1];

    }

    public function add_sliders(img:GImage, i:Int, y:Int, h:Int){
            //var gs0 = new GSlider(y + 24, h - 29, 'drup' + i, 0, _extents[i-1].get('xmin'));
            var exts = image_info.get(img.title).get('extents');
            trace(exts);
            var anchors = image_info.get(img.title).get('anchors');
            var idx:Int = anchors.get('idx');
            var gs0 = new GSlider(y + 24, h - 29, -1 , idx, 0, exts.get('img_width') - 4);
            gs0.i = i - 1;
            gs0.image = img;

            // make sure pad_gs cant cause the min to go beyond the gene
            var xmin = Math.max(rw2pix(exts.get('bpmin') + this.pad_gs, i - 1), 1);
            gs0.x = xmin; // < 1 ? 1: (xmin > _extents[i-1].get('xmin') ?  _extents[i-1].get('xmin') : xmin);
            img.sliders.push(gs0);
            flash.Lib.current.addChild(gs0);

            gs0.addEventListener(MouseEvent.MOUSE_UP, sliderMouseUp);
            //gs0.addEventListener(MouseEvent.MOUSE_OUT, sliderMouseOut);

            var xmax = Math.min(rw2pix(exts.get('bpmax') - this.pad_gs, i - 1), exts.get('img_width'));
            var gs1 = new GSlider(y + 24, h - 29, 1 , idx, 4 , exts.get('img_width'));

            trace('xmax: ' + xmax);
            gs1.x = xmax; 
            gs1.i = i - 1;
            gs1.image = img;
            flash.Lib.current.addChild(gs1);
            gs1.addEventListener(MouseEvent.MOUSE_UP, sliderMouseUp);
            //gs1.addEventListener(MouseEvent.MOUSE_OUT, sliderMouseOut);

            img.sliders.push(gs1);

            gs1.other = gs0;
            gs0.other = gs1;


    }
    // this is a hack for when a mouseup occurs off the slider. this
    // seems to work ok. to trigger intuitive behavior.
    public function sliderMouseOut (e:MouseEvent){
        if(e.buttonDown){ return; }
        if(!(Math.abs(e.target.lastX - e.stageX ) > 15)){ return; }
        e.target._buttonDown = true;
        sliderMouseUp(e);
    }

    public function sliderMouseUp(e:MouseEvent){
            //trace(e.target + ", " +  e.target.updown);
            e.target.stopDrag();
            if(!Reflect.hasField(e.target, '_buttonDown')){ return; }
            if(!e.target._buttonDown){ return; }
            e.target._buttonDown = false;

            if( e.target.updown == 1 && e.target.x - 5 < e.target.other.x){
                e.target.other.x = e.target.x - e.target.updown * 15;
                e.target.other._buttonDown = true;
                e.target.other.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP));
            }
            else if( e.target.updown == -1 && e.target.x + 5 > e.target.other.x){
                e.target.other.x = e.target.x - e.target.updown * 15;
                e.target.other._buttonDown = true;
                e.target.other.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP));
            }

            var x = e.target.x;
            var xupdown = Math.round(pix2relative(x, e.target.i, e.target.updown));
            var exts:Hash<Int> = image_info.get(image_titles[e.target.i]).get('extents');
            var anchs:Hash<Int> = image_info.get(image_titles[e.target.i]).get('anchors');
            var elen = exts.get('bpmax') - exts.get('bpmin') + 1;
            var alen = (anchs.get('xmax') - anchs.get('xmin') + 1) * exts.get('bpp');
            ExternalInterface.call('set_genespace',(e.target.updown == -1) ? 'up' : 'down' , e.target.idx,xupdown, elen, alen);
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
    public var idx:Int;
    public var updown:Int;
    public var bounds:Rectangle;
    public var other:GSlider;
    public var image:GImage;
    private var _buttonDown:Bool;
    public var lastX:Float;
    public var i:Int; // the index of the image it's on
    public var gobe:Gobe;
    public function new(y0:Float, h:Float, updown:Int, idx:Int, bounds_min:Float, bounds_max:Float) {
        super();
        this.idx = idx;
        this.updown = updown;
            
        var g = this.graphics;
        _buttonDown = true;
        bounds = new Rectangle(bounds_min,y0,bounds_max,0);
        // draw the half-circle
        g.moveTo(0, 0);
        g.lineStyle(1,0x000000);
        g.beginFill(0xcccccc);
        g.curveTo(updown * 16, 8, updown, 16);
        g.lineTo(updown, h - 16);
        g.curveTo(updown * 16, h - 8, updown, h);
        g.lineTo(-updown, h);
        g.lineTo(-updown, 0);
        g.lineTo(0, 0);
        g.endFill();

        addEventListener(MouseEvent.MOUSE_DOWN, sliderMouseDown);    
        addEventListener(MouseEvent.MOUSE_MOVE, sliderMouseMove);
        this.y = y0;

    }

    public function sliderMouseMove (e:MouseEvent){
        if(! this._buttonDown){ return; }
        lastX = e.stageX;
    }
    public function sliderMouseDown(e:MouseEvent){
            this._buttonDown = true;
            e.target.startDrag(false, bounds);
    }
}

class GImage extends Sprite {

    private var _imageLoader:Loader;
    private var _bitmap:BitmapData;

    public  var sliders:Array<GSlider>;
    public  var image:Bitmap;
    public  var title:String;
    public  var url:String;
    public  var i:Int;



    public function new(title:String, url:String, i:Int){
        super();
        this.url = url;
        this.title = title;
        this.i   = i;
        sliders = new Array<GSlider>();
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
