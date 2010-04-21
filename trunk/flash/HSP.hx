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
        this.addEventListener(MouseEvent.CLICK, onClick);
    }
    public function draw(?force:Bool=false){
        if(this.drawn){
            this.visible = true;
            return;
        }
        var g = this.graphics;
        g.clear();
        var aa = this.a;
        var bb = this.b;
        if(aa.y > bb.y){
            aa = this.b;
            bb = this.a;
        }
        else {

        }
        // TODO use visible.
        if (this.drawn){
            // probably force because they want to draw every edge. but this is
            // already drawn, so leave it.
            this.drawn = force;
            return;
        }
        trace(aa.y + "," + aa.h);
        var ul = aa.localToGlobal(new flash.geom.Point(0, aa.y + aa.h));
        var ur = aa.localToGlobal(new flash.geom.Point(aa.pxmax - aa.pxmin, aa.y + aa.h));
        trace(ul.y);
        trace(ul.x);

        var ll = bb.localToGlobal(new flash.geom.Point(0, 0));
        var lr = bb.localToGlobal(new flash.geom.Point(bb.pxmax - bb.pxmin, 0));

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
    public function onClick(e:MouseEvent){
        this.visible = false;
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
    public var subtrack:SubTrack;
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
        this.y = -this.subtrack.track_height / 2;
        g.clear();
        this.h = style.feat_height * this.subtrack.track_height;
        g.lineStyle(style.line_width, style.line_color);
        var tw = this.pxmax - this.pxmin;
        g.moveTo(0, h/2);
        g.beginFill(style.fill_color, style.fill_alpha);
        g.lineTo(0, -h/2);
        g.lineTo(tw,-h/2);
        g.lineTo(tw, h/2);
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
        this.ftype = ftype;
        this.fill_color = json.fill_color;
        this.fill_alpha = json.fill_alpha;
        this.line_width = json.line_width;
        this.line_color = json.line_color;
        this.feat_height = json.height;
        this.zindex = json.z ? json.z : 5;
    }
}

class SubTrack extends Sprite {
    public var track:Track;
    public var other:Track;
    public var track_height:Float;
    /// other is a pointer to the other track which shares
    /// pairs with this one.
    public function new(track:Track, other:Track, track_height:Float){
        super();
        this.track = track;
        this.other = other;
        this.track_height = track_height;
        this.draw();
        this.addEventListener(MouseEvent.CLICK, onClick);
    }
    public function onClick(e:MouseEvent){
        if(e.shiftKey){
            for(i in 0 ... this.numChildren){
                var a = cast(this.getChildAt(i), Annotation);
                a.onClick(e);
            }
        }
        else if(e.ctrlKey){
            trace('ctrl');
        }
    }
    public function draw(){
        var sw = flash.Lib.current.stage.stageWidth - 1;
        var g = this.graphics;
        g.lineStyle(0.5, 0.2);
        g.lineTo(sw, 0);
        g.lineStyle(0, 0.0, 0);
        if(this.track == this.other){
            g.beginFill(0, 0.1);
        }
        else { g.beginFill(0, 0); }
        g.moveTo(0, -this.track_height);
        g.lineTo(sw, -this.track_height);
        g.lineTo(sw, 0);
        g.lineTo(0, 0);
        g.endFill();

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
    // key is id of other track.
    public var subtracks:Hash<SubTrack>;

    public  var mouse_down:Bool;
    public  var ttf:MTextField;

    public function new(line:String, track_height:Int){
        super();
        subtracks = new Hash<SubTrack>();
        var l = line.split(",");
        this.id = l[0];
        this.title = l[1];

        this.track_height = track_height;
        this.bpmin = Std.parseInt(l[2]);
        this.bpmax = Std.parseInt(l[3]);
        this.mouse_down = false;
        this.setUpTextField();
        this.bpp = (bpmax - bpmin)/(1.0 * flash.Lib.current.stage.stageWidth);
        this.draw();
        //trace("bpmin-bpmax(rng):" + bpmin +"-" + bpmax + "(" + (bpmax - bpmin) + "), bpp:" + this.bpp);
    }
    public function draw(){
        var g = this.graphics;
        var mid = track_height/2 + 1;
        g.clear();
        var sw = flash.Lib.current.stage.stageWidth - 1;
        g.lineStyle(1, 0.6);
        // the border around this track.
        g.drawRoundRect(0, 0, sw, track_height, 22);

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
