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
import StringTools;
import Util;
import HSP;


class Gobe extends Sprite {

    public static var fontSize:Int = 12;

    public static  var ctx = new LoaderContext(true);

    private var track:String;
    public var cnss:Array<Int>;
    public var stage_height:Int;
    public var stage_width:Float;

    public var wedge_alpha:Float;

    public var drag_sprite:DragSprite;

    public var panel:Sprite; // holds the lines.

    private var _all:Bool;
    public var tracks:Hash<Track>;
    public var annotations:Hash<Annotation>;
    public var styles:Hash<Style>; // {'CDS': CDSINFO }
    public static var edges = new Array<Edge>();

    public var annotations_url:String;
    public var edges_url:String;
    public var tracks_url:String;

    public function clearPanelGraphics(e:MouseEvent){
        while(panel.numChildren != 0){ panel.removeChildAt(0); }
    }
    public function send_html(html:String){
        ExternalInterface.call('Gobe.handle_html', html);
    }

    public static function main(){
        haxe.Firebug.redirectTraces();
        var stage = flash.Lib.current.stage;
        stage.align     = StageAlign.TOP_LEFT;
        stage.scaleMode = StageScaleMode.NO_SCALE;
        stage.addChild( new Gobe());
    }
    private function add_callbacks(){
        ExternalInterface.addCallback("clear_wedges", clear_wedges);
    }

    public function clear_wedges(){
        for(w in edges){ w.visible = false; }
    }
    public function onMouseWheel(e:MouseEvent){
        var change = e.delta > 0 ? 1 : - 1;
        this.wedge_alpha += (change / 10.0);
        if(this.wedge_alpha > 1){ this.wedge_alpha = 1.0; }
        if(this.wedge_alpha < 0.1){ this.wedge_alpha = 0.1; }
        //this.redraw_wedges();
    }
    public function onMouseMove(e:MouseEvent){
        var x = e.localX;
        var tid = this.tracks.keys().next();
        var t = tracks.get(tid);
        trace(x);
        //t.ttf.htmlText = "<p>" + t.pix2rw(x) + "</p>";
    }


    public function new(){
        super();
        var p = flash.Lib.current.loaderInfo.parameters;

        this.drag_sprite = new DragSprite();
        this.wedge_alpha = 0.3;
        this.annotations_url = p.annotations;
        this.edges_url = p.edges;
        this.tracks_url = p.tracks;

        panel = new Sprite(); 
        addChild(panel);
        addChild(this.drag_sprite);
        this.add_callbacks();
        var i:Int;
        geturl(p.style, styleReturn); // this then calls load config

        // the event only gets called when mousing over an HSP.
        addEventListener(MouseEvent.MOUSE_WHEEL, onMouseWheel);
        addEventListener(MouseEvent.MOUSE_MOVE, onMouseMove);

        // this one the event gets called anywhere.
        flash.Lib.current.stage.focus = flash.Lib.current.stage;
        flash.Lib.current.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyPress);
        this.stage_width = flash.Lib.current.stage.stage.stageWidth;
        this.stage_height = flash.Lib.current.stage.stage.stageHeight;

    }
    public function onKeyPress(e:KeyboardEvent){
        if(e.keyCode == 38 || e.keyCode == 40){ // up
            if(e.keyCode == 38 && Gobe.fontSize > 25){ return; }
            if(e.keyCode == 40 && Gobe.fontSize < 8){ return; }
            Gobe.fontSize += (e.keyCode == 38 ? 1 : - 1);
            for(k in tracks.keys()){
                tracks.get(k).ttf.styleSheet.setStyle('p', {fontSize:Gobe.fontSize});
            }
        }
    }
    public function geturl(url:String, handler:Event -> Void){
        trace("getting:" + url);
        var ul = new URLLoader();
        ul.addEventListener(Event.COMPLETE, handler);
        ul.addEventListener(flash.events.ErrorEvent.ERROR, function(e:Event){ trace("failed:" + url); });
        ul.load(new URLRequest(url));
    }

    public function edgeReturn(e:Event){
        trace('edgeReturn');
        var lines:Array<String> = StringTools.ltrim(e.target.data).split("\n");
        // for each track, keep track of the other tracks it maps to.
        var edge_tracks = new Hash<Hash<Int>>();
        trace('looping');
        for(line in lines){
            if(line.charAt(0) == "#" || line.length == 0) { continue; }
            var edge = Util.add_edge_line(line, annotations);
            if (edge == null){ continue; }

            // so here we tabulate all the unique track pairs...
            var aid = edge.a.track.id;
            var bid = edge.b.track.id;

            // for each edge, need to see the annos.tracks it's associated with...
            if(! edge_tracks.exists(aid)) { edge_tracks.set(aid, new Hash<Int>()); }
            if(! edge_tracks.exists(bid)) { edge_tracks.set(bid, new Hash<Int>()); }
            edge_tracks.get(bid).set(aid, 1);
            edge_tracks.get(aid).set(bid, 1);
        }
        initializeSubTracks(edge_tracks);
        addAnnotations();
    }
    private function initializeSubTracks(edge_tracks:Hash<Hash<Int>>){
        // so here, it knows all the annotations and edges, so we figure out
        // the subtracks it needs to show the relationships.
        for(aid in edge_tracks.keys()){
            var btrack_ids = new Array<String>();
            for(bid in edge_tracks.get(aid).keys()){ btrack_ids.push(bid); }
            var ntracks = btrack_ids.length;
            var atrack = tracks.get(aid);

            var i = 1;
            var sub_height = atrack.track_height / (2 * (ntracks + 1));
            for(bid in btrack_ids){
                var btrack = tracks.get(bid);
                for(strand in ['+', '-']){

                    var sub = new SubTrack(atrack, btrack, sub_height);
                    atrack.subtracks.set(strand + bid, sub);
                    atrack.addChildAt(sub, 0);
                    if (strand == '+'){
                        sub.y = i * sub_height;
                    }
                    else {
                        sub.y = atrack.track_height - i * sub_height;
                    }
                    sub.draw();
                }
                i += 1;
            }
        }
    }
    private function addAnnotations(){
        var arr = new Array<Annotation>();
        var a:Annotation;
        for(a in annotations.iterator()){ arr.push(a); }
        arr.sort(function(a:Annotation, b:Annotation):Int {
            return a.style.zindex < b.style.zindex ? -1 : 1;
        });
        for(a in arr){
            if(a.ftype != "HSP"){ a.track.addChild(a); }
            else {
                // loop over the pairs and add to appropriate subtrack based on the id of other.
                for(edge_id in a.edges){
                    var edge = edges[edge_id];
                    var other:Annotation = edge.a == a ? edge.b : edge.a;
                    var strand = other.strand == 1 ? '+' : '-';
                    var sub = a.track.subtracks.get(strand + other.track.id);
                    a.subtrack = sub;
                    sub.addChild(a);
                }
            }
            a.draw();
        }
    }

    public function annotationReturn(e:Event){
        annotations = new Hash<Annotation>();
        var anno_lines:Array<String> = StringTools.ltrim(e.target.data).split("\n");
        for(line in anno_lines){
            if(line.charAt(0) == "#" || line.length == 0){ continue;}
            var a = new Annotation(line, tracks);
            a.style = styles.get(a.ftype);
            annotations.set(a.id, a);
        }
        geturl(this.edges_url, edgeReturn);

    }

    public function trackReturn(e:Event){
        // called by style return.
        this.geturl(this.annotations_url, annotationReturn);
        tracks = new Hash<Track>();
        var lines:Array<String> = e.target.data.split("\n");
        var ntracks = 0;
        for(line in lines){ if (line.charAt(0) != "#" && line.length != 0){ ntracks += 1; }}
        var track_height = Std.int(this.stage_height / ntracks);
        var k = 0;
        for(line in lines){
            if(line.charAt(0) == "#" || line.length == 0){ continue; }
            var t = new Track(line, track_height);
            tracks.set(t.id, t);
            t.y = k * track_height;
            flash.Lib.current.addChildAt(t, 0);
            k += 1;
        }
    }

    public function styleReturn(e:Event){
        this.geturl(this.tracks_url, trackReturn); //

        var strdata:String = e.target.data.replace('"#', '"0x').replace("'#", "'0x");
        var json = JSON.decode(strdata);
        // get the array of feature-type keys.
        var ftypes:Array<String> = Reflect.fields(json);
        styles = new Hash<Style>();
        for(i in 0 ... ftypes.length){
            var ftype = ftypes[i];
            var st = Reflect.field(json, ftype);
            styles.set(ftype, new Style(ftype, st));
        }
    }

    public function pix2rw(px:Float, i:Int):Int {
            trace('TODO');
            return 1;
    }
    public function rw2pix(rw:Float, i:Int):Float {
            trace('TODO');
            return 1;
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

