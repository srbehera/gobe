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

    private var n:Int;
    private var track:String;
    public var cnss:Array<Int>;
    public var stage_height:Int;
    public var stage_width:Int;

    public var wedge_alpha:Float;

    public var drag_sprite:DragSprite;

    public var panel:Sprite; // holds the lines.

    private var _all:Bool;
    public var tracks:Array<Track>;
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
        //this.redraw_wedges();
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

        // this one the event gets called anywhere.
        flash.Lib.current.stage.focus = flash.Lib.current.stage;
        flash.Lib.current.stage.addEventListener(KeyboardEvent.KEY_UP, onKeyPress);
        this.stage_width = flash.Lib.current.stage.stageWidth;
        this.stage_height = flash.Lib.current.stage.stageHeight;

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
    public function geturl(url:String, handler:Event -> Void){
        trace("getting:" + url);
        var ul = new URLLoader();
        ul.addEventListener(Event.COMPLETE, handler);
        ul.load(new URLRequest(url));
    }

    public function edgeReturn(e:Event){
        var lines:Array<String> = StringTools.ltrim(e.target.data).split("\n");
        for(line in lines){
            if(line.charAt(0) == "#" || line.length == 0) { continue; }
            var edge = Util.add_edge_line(line, annotations);
        }
    }

    public function annotationReturn(e:Event){
        annotations = new Hash<Annotation>();
        var lines:Array<String> = StringTools.ltrim(e.target.data).split("\n");
        for(line in lines){
            if(line.charAt(0) == "#" || line.length == 0){ continue;}
            var a = new Annotation(line, tracks);
            a.style = styles.get(a.ftype);
            annotations.set(a.id, a);
            a.track.addChild(a);
            a.draw();
        } 
        geturl(this.edges_url, edgeReturn);
    }

    public function trackReturn(e:Event){
        this.geturl(this.annotations_url, annotationReturn); // 
        tracks = new Array<Track>();
        var lines:Array<String> = e.target.data.split("\n");
        n = 0;
        for(line in lines){ if (line.charAt(0) != "#"){ n += 1; }}
        var track_height = Std.int(this.stage_height / this.n);
        var k = 0;
        for(line in lines){
            if(line.charAt(0) == "#"){ continue; }
            var t = new Track(line, stage_width, track_height);
            tracks.push(t);
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

