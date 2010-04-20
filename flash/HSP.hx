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
    public var track_id:String;
    public var h:Float;

    public var fname:String;
    public function new(line:String, tracks:Hash<Track>){
        super();
        //#id,type,start,end,strand,track,name
        var l = line.split(",");

        this.edges = new Array<Int>();
        this.id = l[0];
        this.ftype = l[1];
        this.bpmin = Std.parseInt(l[2]);
        this.bpmax = Std.parseInt(l[3]);
        this.strand = l[4] == "+" ? 1 : l[4] == "-" ? -1 : 0;
        this.track_id = l[5];
        this.fname = l[6];

        this.track = tracks.get(this.track_id);
        this.pxmin = track.rw2pix(this.bpmin);
        this.pxmax = track.rw2pix(this.bpmax);
        this.x = pxmin;
        this.addEventListener(MouseEvent.CLICK, onClick);
        //trace(this.bpmin + "," + this.bpmax + "=>" + this.pxmin + "," + this.pxmax);

    }
    public function draw(){
        var g = this.graphics;
        g.clear();
        var h = style.feat_height * 20;
        g.lineStyle(style.line_width, style.line_color);
        var ymid = track.track_height / 2 + 2;
        var ymin = ymid - this.strand * h;
        this.y = ymin;
        var tw = this.pxmax - this.pxmin;
        g.moveTo(0, 0);
        g.beginFill(style.fill_color, style.fill_alpha);
        g.lineTo(0, h);
        g.lineTo(tw, h);
        g.lineTo(tw, 0);
        //g.lineTo(0, 0);
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
    public var line_width:Float;
    public var line_color:UInt;
    public var feat_height:Float; // in pct;
    public var zindex:Int;

    public function new(ftype:String, json:Dynamic){
        trace('in new!');
        this.ftype = ftype;
        this.fill_color = json.fill_color;
        this.fill_alpha = json.fill_alpha;
        this.line_width = json.line_width;
        this.line_color = json.line_color;
        this.feat_height = json.height;
        this.zindex = json.z ? json.z : 5;
    }
}

class Track extends Sprite {

    public  var title:String;
    public  var id:String;
    public  var i:Int; // index.
    public  var bpmin:Int;
    public  var bpmax:Int;
    public  var bpp:Float;
    public var track_height:Int;

    public  var mouse_down:Bool;
    public  var ttf:MTextField;

    public function new(line:String, stage_width:Float, track_height:Int){
        super();
        var l = line.split(",");
        this.id = l[0];
        this.title = l[1];

        this.track_height = track_height;
        this.bpmin = Std.parseInt(l[2]);
        this.bpmax = Std.parseInt(l[3]);
        this.mouse_down = false;
        // TODO: check that widht is correct.
        this.setUpTextField();
        this.bpp = (bpmax - bpmin)/(1.0 * flash.Lib.current.stage.stageWidth);
        this.draw();
        trace("stage_width:" + stage_width + ", bpmin-bpmax(rng):" + bpmin +"-" + bpmax + "(" + (bpmax - bpmin) + "), bpp:" + this.bpp);
    }
    public function draw(){
        var g = this.graphics;
        var mid = track_height/2 + 1;
        g.clear();
        var sw = flash.Lib.current.stage.stageWidth - 1;
        g.lineStyle(1, 0.5);
        // the border around this track.
        g.drawRoundRect(0, 0, sw, track_height, 12);

        // the dotted line in the middle.
        g.lineStyle(1, 0x444444, 0.9, false,
                    flash.display.LineScaleMode.NORMAL,
                    flash.display.CapsStyle.ROUND);
        var dash_w = 20;
        var gap_w = 10;
        g.moveTo(gap_w / 2, mid);
        var dx = dash_w;
        while(dx < sw + dash_w) {
            g.lineTo(dx, mid);
            dx += gap_w;
            g.moveTo(dx, mid);
            dx += dash_w;
        }
    }

    public inline function rw2pix(bp:Int){
        var pix = (bp - this.bpmin) / this.bpp;
        //trace(bp + " => " + pix);
        return pix;
    }

    public function setUpTextField(){
        this.ttf = new MTextField();

        ttf.htmlText   = '<p>' + this.title + '</p>';
        ttf.y      = y + 3;
        ttf.x      = 5;
        ttf.multiline = true;

        ttf.border = true;
        ttf.borderColor      = 0xcccccc;
        ttf.opaqueBackground = 0xf4f4f4;
        ttf.autoSize         = flash.text.TextFieldAutoSize.LEFT;
        ttf.styleSheet.setStyle('p', {fontSize: Gobe.fontSize, display: 'inline',
                                    fontFamily: '_sans'});

        this.addChild(ttf);
        ttf.styleSheet.setStyle('p', {fontSize: Gobe.fontSize, display: 'inline',
                                    fontFamily: '_sans'});
    }
}
