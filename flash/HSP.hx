import flash.display.Sprite;
import flash.display.Shape;
import flash.events.MouseEvent;
import flash.geom.Point;
import Gobe;

/*
TODO:
1. handle clicks on highlighted HSPs
2. link to gui for toggle between line and wedge.
3. highlight currently queried HSP
*/

class HSP extends Sprite {
    public var pair:Array<SimRect>;
    public var connector:HSPConnector;
    public var panel:Sprite;

    public var coords1:Array<Int>;
    public var coords2:Array<Int>;
    public var line_color:Int;
    public var as_wedge:Bool;    
    
    public var db_ids:Array<Int>;
 

    
    public function new(panel:Sprite, coords1:Array<Int>, coords2:Array<Int>, 
                                img1:GImage, img2:GImage,
                                line_color:Int, line_width:Int, as_wedge:Bool){
        super();
        this.db_ids = [0, 0];

        this.addEventListener(MouseEvent.CLICK, mouseClick);

        this.panel = panel;
        this.coords1 = coords1;
        this.coords2 = coords2;
        this.line_color = line_color;
        this.as_wedge = as_wedge;
        this.panel.addChild(this);

        var p1 = this.draw(coords1, img1);
        var p2 = this.draw(coords2, img2);

        this.db_ids[0] = coords1[4];
        this.db_ids[1] = coords2[4];
        
        var wedge = new Wedge(coords1, coords2, img1, img2, line_color, line_width, as_wedge);
        this.addChild(wedge); 
        
    }


    public function draw(coords:Array<Int>, img){
        var xy = img.localToGlobal(new flash.geom.Point(coords[0],coords[1]));
        
        var db_id = coords[4]; // this links to the id in the image_data table

        var w = coords[2] - coords[0];
        var h = coords[3] - coords[1];
    
        var r = new SimRect(xy.x, xy.y, w, h);
        this.addChild(r);
    }

    public function mouseClick(e:MouseEvent){
        trace('HSP clicked');
    }

}

class Wedge extends Sprite {
    public var line_color:Int;
    public var line_width:Int;
    public var hsp:HSP;

    public function new(coords1:Array<Int>, coords2:Array<Int>, 
                                img1:GImage, img2:GImage,
                                line_color:Int, line_width:Int, as_wedge:Bool){
        super();
        var xy1a = img1.localToGlobal(new flash.geom.Point(coords1[0] - 0.75, coords1[1]));
        var xy1b = img1.localToGlobal(new flash.geom.Point(coords1[2] - 0.75, coords1[3]));
        
        var xy2a = img2.localToGlobal(new flash.geom.Point(coords2[0] - 0.75, coords2[1]));
        var xy2b = img2.localToGlobal(new flash.geom.Point(coords2[2] - 0.75, coords2[3]));
        this.line_width = line_width;
        this.line_color = line_color;


        if(!as_wedge){
            this.draw_line(xy1a, xy1b, xy2a, xy2b);
        }
        else {
            var strand = coords1[5] < 0 ? -1 : 1;
            this.draw_wedge(xy1a, xy1b, xy2a, xy2b, strand);
        }
    
    }
    public function draw_wedge(xy1a:Point, xy1b:Point, xy2a:Point, xy2b:Point, strand:Int){
            trace('wedged');
            var g = this.graphics;

            g.beginFill(this.line_color, 0.3);
            g.lineStyle(0, this.line_color, 0.6);
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
/*
            var x1mid = (xy1a.x + xy1b.x) / 2;
            var y1mid = (xy1a.y + xy1b.y) / 2;

            var x2mid = (xy2a.x + xy2b.x) / 2;
            var y2mid = (xy2a.y + xy2b.y) / 2;
            

            this.graphics.lineStyle(this.line_width, this.line_color);
            this.graphics.moveTo(x1mid, y1mid);
            this.graphics.lineTo(x2mid, y2mid);
    */
    }
    public function draw_line(xy1a:Point, xy1b:Point, xy2a:Point, xy2b:Point){
            var x1mid = (xy1a.x + xy1b.x) / 2;
            var y1mid = (xy1a.y + xy1b.y) / 2;

            var x2mid = (xy2a.x + xy2b.x) / 2;
            var y2mid = (xy2a.y + xy2b.y) / 2;

            this.graphics.lineStyle(this.line_width, this.line_color);
            this.graphics.moveTo(x1mid, y1mid);
            this.graphics.lineTo(x2mid, y2mid);
    }
}

class SimRect extends Sprite {
    public var color:Int;
    public var hsp:HSP;

    public function new(x:Float, y:Float, w:Float, h:Float) {
        super();
        this.x = x -1.15;
        this.y = y;

        w += 1.0;

        var g = this.graphics;
        g.lineStyle(0, 0x000000);
        g.drawRect(0, 0, w, h);
        
    }
}

class HSPConnector extends Shape {
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
