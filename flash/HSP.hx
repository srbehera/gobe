import flash.display.Sprite;
import flash.display.Shape;
import flash.events.MouseEvent;
import flash.geom.Point;
import flash.utils.Timer;
import flash.events.TimerEvent;
import flash.external.ExternalInterface;
import Gobe;
/*
{
 "tracks": [
     {"title": "At2g26540", "bpmin": 1234, "bpmax": 4567},
     {"title": "At4g16240", "bpmin": 21274, "bpmax": 24567}
     ],
 "annotations": [
     {"type": "CDS", "start": 1259, "end": 1467, "strand": "+", "track": 0, "name": "At2g26540"},
     {"type": "CDS", "start": 1259, "end": 1467, "strand": "+", "track": 1, "name": "At4g16240"}
 ],
 "edge": [[123, 134, 0.6], [144, 171, 0.2]]
}
*/

class Edge extends Sprite {
    public var a:Annotation;
    public var b:Annotation;
    public var strength:Float;
    public var i:Int;
    public function new(a:Annotation, b:Annotation, s:Float, i:Int){
        super();
        this.a = a; this.b = b; this.strength = s; this.i = i;
    }
}

// this is the base class for drawable annotations.
class Annotation extends Sprite {
    public var ftype:String;
    public var pxmin:Float;
    public var pxmax:Float;
    public var strand:Int;
    public var edges:Array<Int>;
    public var bpmin:Int;
    public var bpmax:Int;
    private var style:Style;
    public var track:Track;

    public var fname:String;
    public function new(json:Dynamic, style:Style, track:Track){
        super();
        this.style = style;
        this.ftype = json.type;
        this.bpmin = json.start;
        this.bpmax = json.end;
        this.strand = json.strand ==  "-" ? -1 : json.strand == "+" ? 1 : 0;
        this.track = track;
        this.fname = json.name;
        this.pxmin = track.rw2pix(this.bpmin);
        this.pxmax = track.rw2pix(this.bpmax);
        trace(this.pxmin);
        trace(this.pxmax);
        this.addEventListener(MouseEvent.CLICK, onClick);
    }
    public function draw(){
        var g = this.graphics;
        g.beginFill(style.fill_color, style.fill_alpha);
        g.lineStyle(style.line_width, style.line_color);
        var ymid = track.sheight / 2;
        var yoff = style.offset * track.sheight;
        var ymin = ymid - yoff;
        var ymax = ymin + yoff;
        g.moveTo(this.pxmin, ymin);
        g.lineTo(this.pxmin, ymax);
        g.lineTo(this.pxmax, ymax);
        g.lineTo(this.pxmax, ymin);
        g.lineTo(this.pxmin, ymin);
        g.endFill(); 
    }
    public function onClick(e:MouseEvent){
        ExternalInterface.call('alert', this.fname);
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
    public var sheight:Int;

    public  var mouse_down:Bool;
    public  var ttf:MTextField;

    public function new(title:String, i:Int, bpmin:Int, bpmax:Int,
                        stage_width:Int, sheight:Int){
        super();
        this.title = title;
        this.i   = i;
        this.bpmin = bpmin;
        this.sheight = sheight;
        this.bpmax = bpmax;
        this.mouse_down = false;
        // TODO: check that widht is correct.
        this.bpp  = (1.0 + bpmax - bpmin)/(1.0 * stage_width);

    }

    public inline function rw2pix(x:Int){
        return (x - this.bpmin) / this.bpp;        
    }
}



class HSP extends Sprite {
    public var gobe:Gobe;
    public var pair:Array<SimRect>;
    public var panel:Sprite;

    public var coords1:Array<Int>;
    public var coords2:Array<Int>;
    public var line_color:Int;
    public var wedge_alpha:Float;    

    public var wedge:Wedge;    
    
    public var db_ids:Array<Int>;
 

    
    public function new(panel:Sprite, coords1:Array<Int>, coords2:Array<Int>, 
                                track1:Track, track2:Track,
                                line_color:Int, wedge_alpha:Float){
        super();
        this.db_ids = [0, 0];


        this.panel = panel;
        this.coords1 = coords1;
        this.coords2 = coords2;
        this.line_color = line_color;
        this.wedge_alpha = wedge_alpha;
        this.panel.addChild(this);

        var rect1 = this.make_rect(coords1, track1);
        var rect2 = this.make_rect(coords2, track2);
        this.addChild(rect1);
        this.addChild(rect2);
        this.pair = [rect1, rect2];

        this.db_ids[0] = coords1[4];
        this.db_ids[1] = coords2[4];
        
        this.wedge = new Wedge(coords1, coords2, track1, track2, line_color, wedge_alpha);
        wedge.hsp = this;
        this.addChild(wedge); 
        
    }


    public function make_rect(coords:Array<Int>, track:Track):SimRect {
        var xy = track.localToGlobal(new flash.geom.Point(coords[0],coords[1]));
        
        var db_id = coords[4]; // this links to the id in the image_data table

        var w = coords[2] - coords[0];
        var h = coords[3] - coords[1];
    
        var r = new SimRect(xy.x, xy.y, w, h, track);
        r.hsp = this;
        return r;
    }
    public function redraw(){
        this.pair[0].draw();
        this.pair[1].draw();
        this.wedge.wedge_alpha = this.wedge_alpha;
        this.wedge.draw();
    }
}

class MouseOverableSprite extends Sprite {
    public var hsp:HSP;
    public var mouse_over:Bool;
    public function new(){
        super();
        //this.addEventListener(MouseEvent.ROLL_OVER, onMouseOver);
        //this.addEventListener(MouseEvent.ROLL_OUT, onMouseOut);
        this.addEventListener(MouseEvent.CLICK, onClick);
    }
    public function onDblClick(e:MouseEvent){
        trace('dbl click');
    }
    public function onMouseOver(e:MouseEvent){
        //if(this.mouse_over){ return;}
        //this.mouse_over = true;
        this.hsp.pair[0].draw(true);
        this.hsp.pair[1].draw(true);
        //e.updateAfterEvent();
    }
    public function onMouseOut(e:MouseEvent){
        //if(!this.mouse_over){ return;}
        //this.mouse_over = false;
        this.hsp.pair[0].draw(false);
        this.hsp.pair[1].draw(false);
        //this.removeEventListener(MouseEvent.ROLL_OUT, onMouseOut);
        //e.updateAfterEvent();
    }

    public function onClick(e:MouseEvent){
        if(! e.shiftKey){
            this.hsp.panel.removeChild(this.hsp);
        }
        else {
            // can do something with shift-click.
        }
    }
}

class Wedge extends MouseOverableSprite {
    public var line_color:Int;
    public var strand:Int;
    public var wedge_alpha:Float;
    public var xy1a:Point;
    public var xy1b:Point;
    public var xy2a:Point;
    public var xy2b:Point;

    public function new(coords1:Array<Int>, coords2:Array<Int>, 
                                track1:Track, track2:Track,
                                line_color:Int, wedge_alpha:Float){
        super();
        this.xy1a = track1.localToGlobal(new flash.geom.Point(coords1[0] - 0.75, coords1[1]));
        this.xy1b = track1.localToGlobal(new flash.geom.Point(coords1[2] - 0.75, coords1[3]));
        
        this.xy2a = track2.localToGlobal(new flash.geom.Point(coords2[0] - 0.75, coords2[1]));
        this.xy2b = track2.localToGlobal(new flash.geom.Point(coords2[2] - 0.75, coords2[3]));

        this.line_color = line_color;
        this.strand = coords1[5] < 0 ? -1 : 1;
        this.wedge_alpha = wedge_alpha;


        this.draw();
    }

    public function draw(highlight:Bool=false){
        this.graphics.clear();
        this.draw_wedge(xy1a, xy1b, xy2a, xy2b, strand);
    }

    public function draw_wedge(xy1a:Point, xy1b:Point, xy2a:Point, xy2b:Point, strand:Int){
            var g = this.graphics;
            g.beginFill(this.line_color, this.wedge_alpha);
            g.lineStyle(0, this.line_color, this.wedge_alpha > 0.5 ? 1.0: 0.6);
            g.moveTo(xy1a.x, xy1b.y);
            if (strand == 1){ 
                // go from bl1->tl2->tr2->br1->bl1 then fillRect
                g.lineTo(xy2a.x, xy2a.y);
                g.lineTo(xy2b.x, xy2a.y);
                g.lineTo(xy1b.x, xy1b.y);
            }    
            else {
                g.lineTo(xy2b.x, xy2a.y);
                g.lineTo(xy2a.x, xy2a.y);
                g.lineTo(xy1b.x, xy1b.y);
            }    
            g.endFill();
    }

}

class SimRect extends MouseOverableSprite {
    public var color:Int;
    public var w:Float;
    public var h:Float;
    public var track:Track;

    public function new(x:Float, y:Float, w:Float, h:Float, track:Track) {
        super();
        this.x = x -1.15;
        this.y = y;

        this.w = w + 1.0;
        this.h = h;
        this.track = track;
        this.draw();
        
    }
    public function draw(highlight:Bool=false){
        var g = this.graphics;
        g.clear();
        g.beginFill(0x000000, 0.0);
        if(!highlight){
            g.lineStyle(0, 0x000000);
            g.drawRect(0, 0, this.w, this.h);
        }
        else {
            g.lineStyle(0, 0xaaaaaa);
            g.drawRect(0, 0, this.w, this.h);
            g.lineStyle(1, 0xcccccc);
            g.drawRect(1, 1, this.w - 2, this.h - 2);
             
        }
        g.endFill();
    }
}
