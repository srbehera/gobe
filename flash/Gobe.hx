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

    public static var fontSize:Int = 12;

    public static  var ctx = new LoaderContext(true);

    private var n:Int;
    private var track:String;
    public var cnss:Array<Int>;
    public static var config:String;
    public var sheight:Int;
    public var swidth:Int;

    public var wedge_alpha:Float;

    public var drag_sprite:DragSprite;

    public var panel:Sprite; // holds the lines.

    private var _all:Bool;
    public var tracks:Array<Track>;
    public var annotations:Array<Annotation>;
    public var edges:Array<Edge>;
    public var QUERY_URL:String;
    public var image_titles:Array<String>;


    public function clearPanelGraphics(e:MouseEvent){
        while(panel.numChildren != 0){ panel.removeChildAt(0); }
    }
    public function send_html(html:String){
        ExternalInterface.call('Gobe.handle_html', html);
    }

    private function query_single(e:MouseEvent, track:String, idx:Int):String {
        var i:Int = 0;
        var turl:String;

        this.send_html('');
        //qbx.info.text = '';
        turl = '&x=' + e.localX;
        this._all = false;
        return turl;
    }

    public function query_bbox(bbox:Array<Float>):String {
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
        var track = e.target.url;
        var url = "";
        // TODO
        this.request(url);
    }
    public function request(url:String){
        trace(url);
        var queryLoader = new URLLoader();
        queryLoader.addEventListener(Event.COMPLETE, handleQueryReturn);
        queryLoader.load(new URLRequest(url));
    }


    private function handleQueryReturn(e:Event){
        var json:Array<Dynamic> = JSON.decode(e.target.data).resultset;
        var pair:Hash<Dynamic>;
        trace('TODO');
        // this.send_html('<b>Not showing annotation for multiple hits.</b>');
    }

    public function redraw_wedges(){
        // TODO
    }
    public function removeHSP(hsp:HSP){
        this.panel.removeChild(hsp);
    }

    public static function main(){
        haxe.Firebug.redirectTraces();
        var stage = flash.Lib.current;
        stage.stage.scaleMode = StageScaleMode.NO_SCALE;
        stage.stage.align     = StageAlign.TOP_LEFT;
        stage.addChild( new Gobe());
    }
    private function add_callbacks(){
        ExternalInterface.addCallback("clear_wedges", clear_wedges);
    }

    public function clear_wedges(){
        this.clearPanelGraphics(new MouseEvent(MouseEvent.CLICK));
    }
    public function onMouseWheel(e:MouseEvent){
        var change = e.delta > 0 ? 1 : - 1;
        this.wedge_alpha += (change / 10.0);
        if(this.wedge_alpha > 1){ this.wedge_alpha = 1.0; }
        if(this.wedge_alpha < 0.1){ this.wedge_alpha = 0.1; }
        this.redraw_wedges();
    }


    public function new(){
        super();
        var p = flash.Lib.current.loaderInfo.parameters;
        Gobe.config  = p.config;

        this.drag_sprite = new DragSprite();
        this.wedge_alpha = 0.3;

        panel = new Sprite(); 
        addChild(panel);
        addChild(this.drag_sprite);
        this.add_callbacks();
        var i:Int;
        loadConfig(); // 

        // the event only gets called when mousing over an HSP.
        addEventListener(MouseEvent.MOUSE_WHEEL, onMouseWheel);

        // this one the event gets called anywhere.
        flash.Lib.current.stage.focus = flash.Lib.current.stage;
        flash.Lib.current.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyPress);
        this.swidth = flash.Lib.current.stage.stageWidth;
        this.sheight = flash.Lib.current.stage.stageHeight;

    }
    public function onKeyPress(e:KeyboardEvent){
        // if they pressed 'm' or 'M'
        if(e.keyCode == 38){ // up
            if(Gobe.fontSize > 25){ return; }
            Gobe.fontSize += 1;
            for(track in tracks){
                track.ttf.styleSheet.setStyle('p', {fontSize:Gobe.fontSize});
            }
        }
        else if (e.keyCode == 40){ // down
            if(Gobe.fontSize < 5){ return; }
            Gobe.fontSize -= 1;
            for(track in tracks){
                track.ttf.styleSheet.setStyle('p', {fontSize:Gobe.fontSize});
            }
        }

    }

    public function loadConfig(){
        var ul = new URLLoader();
        ul.addEventListener(Event.COMPLETE, configReturn);
        ul.load(new URLRequest(Gobe.config));
    }


    public function configReturn(e:Event){
        var strdata:String = e.target.data;
        var json = JSON.decode(strdata);
        initTracks(json.tracks);
        initAnnotations(json.annotations, json.edges);
    }

    public function pix2rw(px:Float, i:Int):Int {
            trace('TODO');
            return 1;
    }
    public function rw2pix(rw:Float, i:Int):Float {
            trace('TODO');
            return 1;
    }

    public function initAnnotations(annotations_json:Array<Dynamic>, edges_json:Array<Dynamic>){
        annotations = new Array<Annotation>();
        var i:Int;
        for(i in 0 ... annotations_json.length){
            var a:Dynamic = annotations_json[i];
            // TODO: it's not an Annotation, it's a lookup based on type...
            var an = new Annotation(a);
            annotations.push(an);
            tracks[an.track_i].addChild(an);
            an.draw(tracks[an.track_i]);
            
        }
        // now add info to the annotations based on info in edges.
        edges = new Array<Edge>();
        for(i in 0 ... edges_json.length){
            var ea:Array<Float> = edges_json[i];
            var e0 = Std.int(ea[0]);
            var e1 = Std.int(ea[1]);
            var edge = new Edge(annotations[e0],
                                annotations[e1], ea[2], i);
            annotations[e0].edges.push(e1);
            annotations[e1].edges.push(e0);
            edges.push(edge);
        } 
    }

    public function initTracks(tracks_json:Array<Dynamic>){
        tracks = new Array<Track>();
        this.n = tracks_json.length;
        for(k in 0... this.n){
            var t:Dynamic = tracks_json[k];
            tracks[k] = new Track(t.title, t.k, t.bpmin, t.bpmax, swidth);
            tracks[k].y = k * this.sheight / this.n;
            flash.Lib.current.addChildAt(tracks[k], 0);
            setUpTextField(tracks[k]);
        }
    }
    

    public function setUpTextField(track:Track){
        var ttf = new MTextField();
        track.ttf = ttf;
        
        ttf.htmlText   = '<p>' + track.title + '</p>';
        ttf.y      = y ; 
        ttf.x      = 15;
        ttf.multiline = true;
  
        ttf.border = true; 
        ttf.borderColor      = 0xcccccc;
        ttf.opaqueBackground = 0xf4f4f4;
        ttf.autoSize         = flash.text.TextFieldAutoSize.LEFT;
        ttf.styleSheet.setStyle('p', {fontSize: Gobe.fontSize, display: 'inline',
                                    fontFamily: '_sans'});

        track.addChild(ttf);
        ttf.styleSheet.setStyle('p', {fontSize: Gobe.fontSize, display: 'inline',
                                    fontFamily: '_sans'});
    }
}

class MTextField extends TextField {
    public function new(){
        super();
        this.styleSheet = new StyleSheet();
    }
}

// this makes the gray selection triangle.
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

