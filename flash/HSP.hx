import flash.display.Sprite;
import flash.display.Shape;
import flash.events.MouseEvent;
import flash.geom.Point;
import flash.utils.Timer;
import flash.events.TimerEvent;
import flash.external.ExternalInterface;
import Gobe;

class Edge extends Sprite {
    public var a:Annotation;
    public var b:Annotation;
    public var strength:Float;
    public var i:Int;
    public var drawn:Bool;
    public function new(a:Annotation, b:Annotation, s:Float){
        super();
        this.a = a; this.b = b; this.strength = s;
        this.drawn = false;
    }
    public function draw(?force:Bool=false){
        var g = this.graphics;
        g.clear();
        var aa = this.a;
        var bb = this.b;
        if(aa.y > bb.y){
            aa = this.b;
            bb = this.a;
        }
        // TODO use visible.
        if (this.drawn){
            // probably force because they want to draw every edge. but this is
            // already drawn, so leave it.
            this.drawn = force;
            return;
        }
        var ul = aa.track.localToGlobal(new flash.geom.Point(aa.pxmin, aa.y + aa.h));
        var ur = aa.track.localToGlobal(new flash.geom.Point(aa.pxmax + 1, aa.y + aa.h));

        var ll = bb.track.localToGlobal(new flash.geom.Point(bb.pxmin, bb.y));
        var lr = bb.track.localToGlobal(new flash.geom.Point(bb.pxmax + 1, bb.y));

        g.beginFill(0x0000ff, 0.3);
        g.lineStyle(0, 0.4);
        g.moveTo(ul.x, ul.y);
        g.lineTo(ur.x, ur.y);
        g.lineTo(lr.x, lr.y);
        g.lineTo(ll.x, ll.y);
        g.lineTo(ul.x, ul.y);
        g.endFill();
        this.drawn = true;
    }
}

// this is the base class for drawable annotations.
class Annotation extends Sprite {
    public var ftype:String;
    public var id:String; // key for anntations hash.
    public var pxmin:Float;
    public var pxmax:Float;
    public var strand:Int;
    public var edges:Array<Int>;
    public var bpmin:Int;
    public var bpmax:Int;
    public var style:Style;
    public var track:Track;
    public var track_id:Int;
    public var h:Float;

    public var fname:String;
    public function new(line:String, tracks:Array<Track>){
        super();
        //#id,type,start,end,strand,track,name
        var l = line.split(",");

        this.edges = new Array<Int>();
        this.id = l[0];
        this.ftype = l[1];
        this.bpmin = Std.parseInt(l[2]);
        this.bpmax = Std.parseInt(l[3]);
        this.strand = l[4] == "+" ? 1 : l[4] == "-" ? -1 : 0;
        this.track_id = Std.parseInt(l[5]);
        this.fname = l[6];
        
        this.track = tracks[this.track_id];
        this.pxmin = track.rw2pix(this.bpmin);
        this.pxmax = track.rw2pix(this.bpmax);
        this.addEventListener(MouseEvent.CLICK, onClick);

    }
    public function draw(){
        this.h = this.style.offset * this.track.stage_height;
        var g = this.graphics;
        g.beginFill(style.fill_color, style.fill_alpha);
        g.lineStyle(style.line_width, style.line_color);
        var ymid = track.stage_height / 2;
        var ymin = ymid - h;
        this.y = ymin;
        this.x = this.pxmin;
        var tw = this.pxmax;
        g.moveTo(0, 0);
        g.lineTo(0, h);
        g.lineTo(tw, h);
        g.lineTo(tw, 0);
        g.lineTo(0, 0);
        g.endFill(); 
    }
    public function onClick(e:MouseEvent){
        var te = this.edges;
        for(i in 0 ... te.length){
            Gobe.edges[te[i]].draw();
        }
        //ExternalInterface.call('alert', this.fname);
    }

}

class Style {
    public var ftype:String;
    public var fill_color:UInt;
    public var fill_alpha:Float;
    public var offset:Float;
    public var line_width:Float;
    public var line_color:UInt;

    public function new(ftype:String, json:Dynamic){
        this.ftype = ftype;
        this.fill_color = json.fill_color;
        this.fill_alpha = json.fill_alpha;
        this.offset = json.offset;
        this.line_width = json.line_width;
        this.line_color = json.line_color;
    }
}

class Track extends Sprite {

    public  var title:String;
    public  var i:Int; // index.
    public  var bpmin:Int;
    public  var bpmax:Int;
    public  var bpp:Float;
    public var stage_height:Int;

    public  var mouse_down:Bool;
    public  var ttf:MTextField;

    public function new(line:String, stage_width:Int, stage_height:Int){
        super();
        var l = line.split(",");
        this.title = l[0];
        
        this.stage_height = stage_height;
        this.bpmin = Std.parseInt(l[1]);
        this.bpmax = Std.parseInt(l[2]);
        this.mouse_down = false;
        // TODO: check that widht is correct.
        this.bpp  = (0.001 + bpmax - bpmin)/(1.0 * stage_width);

    }

    public inline function rw2pix(x:Int){
        return (x - this.bpmin) / this.bpp;        
    }
}
