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
import flash.geom.Point;
import flash.geom.Rectangle;
import flash.net.URLRequest;
import flash.net.URLLoader;
import flash.system.LoaderContext;
import flash.text.TextField;
import flash.text.TextFormat;
import flash.text.StyleSheet;
import flash.utils.Timer;
import flash.events.TimerEvent;
import hxjson2.JSON;
import HSP;


class Gobe extends Sprite {

    public static  var ctx = new LoaderContext(true);
    private static var gobe_url = '/CoGe/gobe/';
    private static var img_url = '/CoGe/gobe/tmp/';

    // gobe_url and n are sent in on the url.
    private var n:Int;
    private var pad_gs:Int; // how many bp in to put the bars from the edge of the image
    private var img:String;
    public var cnss:Array<Int>;

    public var as_wedge:Bool;
    public var line_width:Int;
    

    public var drag_sprite:DragSprite;

    private var _heights:Array<Int>;

    public var base_name:String;
    //public var qbx:QueryBox;
    // hold the hsps so we know if one contained a click
    public var hsps:Array<HSP>;
    public var panel:Sprite; // holds the lines.

    private var _all:Bool;
    public var imgs:Array<GImage>;
    public var image_info:Hash<Dynamic>;
    public var QUERY_URL:String;
    public var image_titles:Array<String>;


    public function clearPanelGraphics(e:MouseEvent){
        while(panel.numChildren != 0){ panel.removeChildAt(0); }
    }
    public function send_html(html:String){
        ExternalInterface.call('Gobe.handle_html', html);
    }

    private function query_single(e:MouseEvent, img:String, idx:Int):String {
        var i:Int = 0;
        var turl:String;
         
        this.send_html('');
        //qbx.info.text = '';
        turl = '&x=' + e.localX;
        this._all = false;
        return turl;
    }

    public function query_bbox(e:MouseEvent, String, idx:Int, bbox:Array<Float>):String {
        var turl:String = '&bbox=' + bbox.join(",");
        this._all = true;
        return turl;
    }
    // needed because cant use default args like in query() 
    // with addEventListener expecting a different sig.
    private function _query(e:MouseEvent){
        query(e);
    }

    private function query(e:MouseEvent, ?bbox:Array<Float>){
        var img = e.target.url;
        var idx:Int = image_info.get(image_titles[e.target.i]).get('anchors').get('idx');
        var url = this.QUERY_URL + '&y=' + e.localY + '&img=' + idx + '&db=' + base_name;

        if (bbox != null){
            url += query_bbox(e, img, idx, bbox);
            this._all = true;
        }
        else if(e.shiftKey){
            url      += '&all=1';
            this._all = true;
        }
        else if(! e.shiftKey){
            var turl = query_single(e, img, idx);
            if(turl == ""){ return; }
            url += turl;
        } 

        trace(url);
        var queryLoader = new URLLoader();
        queryLoader.addEventListener(Event.COMPLETE, handleQueryReturn);
        queryLoader.load(new URLRequest(url));
    }


    private function handleQueryReturn(e:Event){
        var json:Array<Dynamic> = JSON.decode(e.target.data).resultset;
        var pair:Hash<Dynamic>;
        for(pair in json){
            if(!this._all){
                //trace(pair);
                
                this.send_html("<p><a target='_blank' href='" + pair.link + "'>full annotation</a></p>&#10;&#10;" +
                                "<p>" + pair.annotation + "</p>");
                //qbx.info.htmlText = "<p><a target='_blank' href='" + pair.link + "'>full annotation</a></p>&#10;&#10;";
                //qbx.info.htmlText += "<p>" + pair.annotation + "</p>";
            }
            if(! pair.has_pair){ continue; }

            var idx:Int = 0;
            var fields:Array<String> = Reflect.fields(pair.features);
            fields.sort(function(a:String, b:String) { return (a < b) ? -1 : 1;} );
            var l = fields.length;
            while (idx < l){
                var fhsp1 = fields[idx++];
                var fhsp2 = fields[idx++];
                var coords1:Array<Int> = Reflect.field(pair.features, fhsp1);
                var coords2:Array<Int> = Reflect.field(pair.features, fhsp2);

                var img1_key = base_name + '_' + fhsp1.substr(3) + ".png";
                var img1:GImage = this.imgs[image_info.get(img1_key).get('i')];

                var img2_key = base_name + '_' + fhsp2.substr(3) + ".png";
                var img2:GImage = this.imgs[image_info.get(img2_key).get('i')];

                // make sure were not adding an hsp that's already drawn.
                var ehsp:HSP;
                var existing:Bool = false;
                for(ehsp in this.hsps){
                    // can do this by checking the image_id
                    if(coords1[4] == ehsp.coords1[4] || coords2[4] == ehsp.coords1[4]){
                        existing = true;
                        if(ehsp.stage == null){
                            ehsp.as_wedge = this.as_wedge;
                            ehsp.wedge.line_width = this.line_width;
                            this.panel.addChild(ehsp);
                            ehsp.redraw();
                        } 
                        break;
                    } 
                }

                if(! existing){
                    var hsp = new HSP(this.panel, coords1, coords2, img1, img2, pair.color, this.line_width, this.as_wedge);
                    this.hsps.push(hsp);
                    hsp.gobe = this;
                }
        
            }
        }
        // if it was showing all the hsps, dont show the annotation.
        if( this._all){
            this.send_html('<b>Not showing annotation for multiple hits.</b>');
            //qbx.info.htmlText = '<b>Not showing annotation for multiple hits.</b>';
            return;
        }
        //qbx.show();
    }
    public function redraw_wedges(){
        for(ehsp in this.hsps){
            ehsp.as_wedge = this.as_wedge;
            ehsp.wedge.line_width = this.line_width;
            ehsp.redraw();
        }
    }
    public function removeHSP(hsp:HSP){
        this.panel.removeChild(hsp);
    }

    public static function main(){
        haxe.Firebug.redirectTraces();
        flash.Lib.current.stage.scaleMode = StageScaleMode.NO_SCALE;
        flash.Lib.current.stage.align     = StageAlign.TOP_LEFT;
        flash.Lib.current.addChild( new Gobe());
    }
    private function add_callbacks(){
        ExternalInterface.addCallback("clear_wedges", clear_wedges);
        ExternalInterface.addCallback("set_linewidth", set_linewidth);
        ExternalInterface.addCallback("set_connector", set_connector);
    }

    public function clear_wedges(){
        this.clearPanelGraphics(new MouseEvent(MouseEvent.CLICK));
    }
    public function set_linewidth(lw:String){
        this.line_width = Std.parseInt(lw);
        this.redraw_wedges();
    }
    public function set_connector(conn:String){
        this.as_wedge = conn != 'line';
        this.redraw_wedges();
    }


    public function new(){
        super();
        var p = flash.Lib.current.loaderInfo.parameters;
        Gobe.gobe_url  = p.gobe_url;
        this.QUERY_URL = Gobe.gobe_url + 'query.pl?';
        this.base_name = p.base_name;
        Gobe.img_url   = p.img_url;
        this.pad_gs    = p.pad_gs;
        this.n         = p.n;

        this.drag_sprite = new DragSprite();
        this.as_wedge = true;
        this.line_width = 3;

        panel = new Sprite(); 
        addChild(panel);
        addChild(this.drag_sprite);
        this.add_callbacks();
        _heights = [];
        this.hsps = [];
        var i:Int;
        for(i in 0...p.n){ _heights[i] = 0; }
        getImageInfo(); // this calls initImages();
        //qbx = new QueryBox(Gobe.gobe_url, this);
        //qbx.x =  1030;
        //qbx.show();
        //qbx.clear_sprite.addEventListener(MouseEvent.CLICK, clearPanelGraphics);

    }

    public function getImageInfo(){
        var ul = new URLLoader();
        ul.addEventListener(Event.COMPLETE, imageInfoReturn);
        ul.load(new URLRequest(this.QUERY_URL + '&get_info=1&db=' + this.base_name));
    }

    public function imageInfoReturn(e:Event){
            var strdata:String = e.target.data;
            image_info = new Hash<Dynamic>();

            var json = JSON.decode(strdata);
            // CONVERT THE JSON data into a HASH: sigh.
            image_titles = ['a','b'];
            for( title in Reflect.fields(json)){
                if (title == "CNS"){ continue; }
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
            initImages();
    }


    public function pix2rw(px:Float, i:Int):Int {
        var exts = image_info.get(image_titles[i]).get('extents');
        return Math.round(exts.get('bpmin') + px * exts.get('bpp'));
    }
    public function rw2pix(rw:Float, i:Int):Float {
        var exts = image_info.get(imgs[i].title).get('extents');
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
            imgs[k] = new GImage(title, Gobe.img_url +  title,  k);
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
            ttf.multiline = true;
            ttf.border = true; 
            if(ttf.text.indexOf('Reverse Complement') != -1  ) {
                ttf.textColor = 0xff0000;
            }
            ttf.borderColor      = 0xcccccc;
            ttf.opaqueBackground = 0xf4f4f4;
            ttf.autoSize         = flash.text.TextFieldAutoSize.LEFT;

            flash.Lib.current.addChildAt(ttf, 1);
            // TODO move this onto the Rectangles.
            img.addEventListener(MouseEvent.CLICK, _query, false);
            //var stage = flash.Lib.current;
            img.addEventListener(MouseEvent.MOUSE_DOWN, mouseDown);
            img.addEventListener(MouseEvent.MOUSE_MOVE, mouseMove);
            img.addEventListener(MouseEvent.MOUSE_UP, mouseUp);
            i++;
            add_sliders(img, i, y, h);
             
            img.addEventListener(MouseEvent.MOUSE_UP, imageMouseUp, true);
            //img.dispatchEvent(new MouseEvent(MouseEvent.MOUSE_UP));
            y+=h;
        }
        this.addEventListener(MouseEvent.MOUSE_UP, stageMouseUp);
        this.addEventListener(MouseEvent.MOUSE_MOVE, stageMouseMove);
        //this.dispatchEvent(new GEvent(GEvent.ALL_LOADED));
    }
    public function mouseDown(e:MouseEvent){
        e.target.mouse_down = true;
        var d = this.drag_sprite;
        d.graphics.clear();
        d.startx = e.stageX;
        d.starty = e.stageY;
    }

    public function mouseMove(e:MouseEvent){
        if(! e.target.mouse_down){ return; }
        if (!e.buttonDown){
            var e2 = new MouseEvent(MouseEvent.MOUSE_UP, false, false, e.localX, e.localY);
            this.dispatchEvent(e2);
            return;
        }
        this.drag_sprite.do_draw(e.stageX, e.stageY);
    }
    public function stageMouseMove(e:MouseEvent){
        var img:GImage;
        for (img in this.imgs){
            img.dispatchEvent(e);
        }
    
    }

    public function stageMouseUp(e:MouseEvent){
        var img:GImage;
        for (img in this.imgs){
            img.dispatchEvent(e);
        }
    
    }
    public function mouseUp(e:MouseEvent){
        if(! e.target.mouse_down){ return; }
        e.target.mouse_down = false;
        var d = this.drag_sprite;
        if (Math.abs(e.stageX - d.startx) < 4){
            d.graphics.clear();
            return;
        }
        var xmin = Math.min(d.startx, e.stageX);
        var xmax = Math.max(d.startx, e.stageX);
        var ymin = Math.min(d.starty, e.stageY);
        var ymax = Math.max(d.starty, e.stageY);
        for(i in 0... e.target.i){
            ymin -= _heights[i];
            ymax -= _heights[i];
        }
    
        query(e, [xmin, ymin, xmax, ymax]);
        var t = new Timer(600);
        t.addEventListener(TimerEvent.TIMER, function(e:TimerEvent){ d.graphics.clear(); } );
        t.start();
        
        
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

            gs0.addEventListener(MouseEvent.MOUSE_UP, sliderMouseUp, false);
            //gs0.addEventListener(MouseEvent.MOUSE_OUT, sliderMouseOut);

            var xmax = Math.min(rw2pix(exts.get('bpmax') - this.pad_gs, i - 1), exts.get('img_width'));
            var gs1 = new GSlider(y + 24, h - 29, 1 , idx, 4 , exts.get('img_width'));

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
            ExternalInterface.call('Gobe.set_genespace',(e.target.updown == -1) ? 'up' : 'down' , e.target.idx,xupdown, elen, alen);
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
    public  var mouse_down:Bool;



    public function new(title:String, url:String, i:Int){
        super();
        this.url = url;
        this.title = title;
        this.i   = i;
        sliders = new Array<GSlider>();
        _imageLoader = new Loader();
        _imageLoader.load(new URLRequest(url));
        _imageLoader.contentLoaderInfo.addEventListener(Event.COMPLETE, onComplete);
    this.mouse_down = false;
    }

    private function onComplete(event:Event) {
        image = cast(_imageLoader.content, Bitmap);
        _bitmap = image.bitmapData;
        dispatchEvent(new GEvent(GEvent.LOADED));
        addChild(image);
    }

}

class DragSprite extends Sprite {
    public var startx:Float;
    public var starty:Float;
    public function new(){
        super();
    }
    public function do_draw(eX:Float, eY:Float){ 
        this.graphics.clear();
        this.graphics.lineStyle(1, 0xcccccc);
        var xmin = Math.min(this.startx, eX);
        var xmax = Math.max(this.startx, eX);
        var ymin = Math.min(this.starty, eY);
        var ymax = Math.max(this.starty, eY);

        this.graphics.beginFill(0xcccccc, 0.2);
        this.graphics.drawRect(xmin, ymin, xmax - xmin, ymax - ymin);
        this.graphics.endFill();
    }
}


class GEvent extends Event {
    public static var LOADED = "LOADED";
    //public static var ALL_LOADED = "ALL_LOADED";
    public function new(type:String){
        super(type);
    }
}

