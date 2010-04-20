import HSP;
import Gobe;

class Util {
    public static function add_edge_line(line:String, annotations:Hash<Annotation>):Null<Edge>{
        var l = line.split(",");
        var a = annotations.get(l[0]);
        var b = annotations.get(l[1]);
        var strength = Std.parseFloat(l[2]);
        if (a == null || b == null){ return null; }

        var edge = new Edge(a, b, strength);
        var nedges = Gobe.edges.length;
        edge.a.edges.push(nedges);
        edge.b.edges.push(nedges);
        Gobe.edges.push(edge);
        flash.Lib.current.addChild(edge);
        return edge;
    }

}
