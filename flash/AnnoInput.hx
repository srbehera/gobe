import fcomponentshx.FComponents;
import fcomponentshx.FLabel;
import fcomponentshx.FTextInput;
import fcomponentshx.FListView;
import fcomponentshx.FCheckButton;
import fcomponentshx.FButton;

import flash.display.MovieClip;
import flash.display.DisplayObjectContainer;
import flash.display.Sprite;
import flash.events.MouseEvent;
import flash.events.Event;
import flash.external.ExternalInterface;

import flash.net.URLRequest;
import flash.net.URLLoader;

class FComboBoxHeaderArrowGFX extends MovieClip{}
class FComboBoxHeaderGFX extends MovieClip{}
class FListViewGFX extends MovieClip{}
class FRadioButtonCheckedGFX extends MovieClip{}
class FRadioButtonUncheckedGFX extends MovieClip{}
class FCheckButtonCheckedGFX extends MovieClip{}
class FCheckButtonUncheckedGFX extends MovieClip{}
class FButtonGFX extends MovieClip{}
class FTextInputGFX extends MovieClip{}
class FProgressBarGFX extends MovieClip{}
class FProgressBarFillGFX extends MovieClip{}

class AnnoInput extends MovieClip {

    static var keywords:Array<String> = ['BIGFOOT', 'APPRESSED', 'DUPLICATE HSPs', 'SPECIAL', 'NGCS NEARBY'];
    var keywords_label          : FLabel;
    static var keywords_cbxs    : FListView;
    
    static var annos:Array<String> = ['EXON NOT CALLED', 'FALSE EXON CALLED', 'SPLITS AND FUSIONS', 'USED SB MODEL FOR MASK'];
    var anno_label              : FLabel;
    static var anno_cbxs        : FListView;

    var qdups_label            : FLabel;
    var qdups_txt              : FTextInput;
    var sdups_label            : FLabel;
    var sdups_txt              : FTextInput;


    var notes_label             : FLabel;
    static var notes_txt        : flash.text.TextField;

    var revisit_label: FLabel;
    static var revisit          : FCheckButton;

    var save_button             : FButton;
    var remove_button           : FButton;

    var new_genespace_button    : FButton;



    public var gobe:Gobe;

    static var python:haxe.remoting.AsyncConnection = haxe.remoting.AsyncConnection.amfConnect( 'service.wsgi' );
    
    var genespace_id:Int;
    private var new_anchors:Array<Dynamic>; // save the bp coords of the anchors, + gobe.base_name

    public function new (mc:MovieClip, genespace_id:Int, gobe:Gobe) {
        super();
        this.gobe = gobe;
        this.genespace_id = genespace_id;
        // FComponents.FTextInputGFXRect = new flash.geom.Rectangle ( 3, 3, 58, 10 );
        // Add your own CSS style:
        var css = FComponents.css;
        css.setStyle( "header", { fontFamily  : "Arial", fontStyle   : "italic", fontSize    : 15, display     : "inline" });
        css.setStyle( "title", { fontFamily  : "Arial", fontStyle   : "italic", fontSize    : 20, display     : "inline" });
        css.setStyle( "p", { color       : "#333333", fontWeight  : "bold", fontFamily  : "Arial", fontSize    : 10 }); 
        css.setStyle( "e", { color       : "#ff3333", fontWeight  : "bold", fontFamily  : "Arial", fontSize    : 14 }); 

        var x:Float = 0.0;
        keywords_label = new FLabel( mc, "<header>Keywords</header>", { x: x, y: null } );
        keywords_cbxs  = new FListView( mc, keywords, keywords, { x: x, y : 20.0 }, null, true, true );

        x = 150.0; 
        anno_label = new FLabel(mc, "<header>Annotation Issues</header>", { x: x, y: null } );
        anno_cbxs  = new FListView(mc, annos, annos, { x : x, y : 20.0 }, null, true, true );

        var y = 105.0;
        qdups_label = new FLabel(mc, "<header>Duplicates on Query:</header>", {x: x - 25., y: y});
        qdups_txt = new FTextInput(mc, "0", {x: x + 170., y: y + 3}, 18, 18);
        y += 20.0;
        sdups_label = new FLabel(mc, "<header>Duplicates on Subject:</header>", {x: x - 25., y: y});
        sdups_txt = new FTextInput(mc, "0", {x: x + 170., y: y + 3}, 18, 18);


        x = 0.0;  
        y += 20;
        notes_label = new FLabel(mc, "<header>Notes</header>", { x: x, y: y } );
        notes_txt = new ATextInput(mc, "", x, y + 20);

        y += 135.0;
        revisit = new FCheckButton(mc, "REVISIT", { x:x, y: y});
        save_button = new FButton(mc, "<header>Save</header>", {x: 90.0 , y: y}, python_save);

        remove_button = new FButton(mc, "<header>Remove Genespace</header>", {x: 150.0 , y: y}, python_remove);

        new_genespace_button = new FButton(mc, "<e>New Genespace</e>", {  x: 150.0, y: y + 30.}, new_genespace);

                        
    }
    public function new_genespace(e:MouseEvent){
        new_anchors = [];
        ExternalInterface.call('alert', 'click at the anchor point for QUERY of the new genespace');
        gobe.imgs[0].addEventListener(MouseEvent.CLICK, called_genespace_query, false, 100 );
    }

    // so when they click the new genespace buttons, it first gets a
    // click on the query image, converts to rw, then asks for a click
    // on the subject image, converts to rw, then sends those coords
    // to python and adds them as anchors to the db.
    public function called_genespace_query(e:MouseEvent){
            e.stopPropagation(); e.stopImmediatePropagation();
            ExternalInterface.call('alert', 'click at the anchor point for SUBJECT of the new genespace');
            gobe.imgs[1].addEventListener(MouseEvent.CLICK, called_genespace_subject, false, 100 );
            e.target.removeEventListener(e.type, called_genespace_query);
            new_anchors.push(gobe.pix2rw(e.stageX, 0));
    }
    public function called_genespace_subject(e:MouseEvent){
            e.stopPropagation(); e.stopImmediatePropagation();
            e.target.removeEventListener(e.type, called_genespace_query);
            new_anchors.push(gobe.pix2rw(e.stageX, 1));
            new_anchors.push(gobe.base_name);
            python_new_genespace(new_anchors);
    }

    public function python_new_genespace(anchors:Array<Dynamic>){
       python.new_genespace.call(anchors, function(s){
            ExternalInterface.call("alert", 'new genespace added at anchors: ' + s 
                + '\nrefresh the list of links to see the changes');
       });
    }

    public function python_remove(e: MouseEvent){
        python.remove.call([genespace_id], function(s){
            trace("TODO:" + s);
        });
    }
    public function python_save(e: MouseEvent){
        trace(genespace_id);

        var hsp_ids = new Array<Array<Int>>();
        for(gl in gobe._lines){
            if(gl.db_id1 > gl.db_id2){
                trace('BAD BAD BAD BAD BAD');
            }
            hsp_ids.push([gl.db_id1, gl.db_id2]);
        }
        var args = [{
             genespace_id:genespace_id
             ,keywords:keywords_cbxs.selectedIndexes
             ,annos:anno_cbxs.selectedIndexes
             ,notes:notes_txt.text
             ,revisit: revisit.checked
             ,hsp_ids: hsp_ids
             ,qdups: Std.parseInt(qdups_txt.text)
             ,qextents:gobe.get_slider_locs_rw(0)
             ,sextents:gobe.get_slider_locs_rw(1)
             ,sdups: Std.parseInt(sdups_txt.text)
             ,base_name: gobe.base_name
          }];
        trace('calling save with: ' + args);
        python.save.call(args, function(s){trace(s);});
    }

    
   public function python_load_callback(s:Dynamic){  
        trace(s);
        if(!s) { return; }

        anno_cbxs.setSelectedIndexes(Reflect.field(s, 'annos'));
        keywords_cbxs.setSelectedIndexes(Reflect.field(s, 'keywords'));
        notes_txt.text = Reflect.field(s, 'notes');
        qdups_txt.setText(Reflect.field(s, 'qdups').toString());
        sdups_txt.setText(Reflect.field(s, 'sdups').toString());
        var features:Array<Dynamic> = Reflect.field(s, 'features');
        // TODO: only do this on the initial load. otherwise, it
        // will overwrite the changes.
        for(feat in features){
            // TODO: why do i have to reverse these? bug elsewhere.
            trace("feat:" + feat);
            for(img in ['img1', 'img2']){
                var coords:Array<Int> = Reflect.field(feat, img);
                var img_idx:Int = Std.parseInt(img.substr(3)) - 1;
                gobe.drawHsp(coords, img_idx);
            }
        }
        gobe.drawLines();
        revisit.setChecked(Reflect.field(s,'revisit'));
        var sextents = Reflect.field(s, 'sextents');
        var qextents = Reflect.field(s, 'qextents');
        //trace(sextents);
        //trace(qextents);

    }

    public function python_predict(){
        // TODO: should only do this if it hasnt be seen before.
        // probably in the callback ...
        trace("CALLING PREDICT");
        python.predict.call([gobe.base_name], python_predict_callback);
    }

    public function python_predict_callback(pairs:Array<Array<Array<Int>>>){
        trace(pairs);
        if(pairs == null){ return; }
        var pair = new Array<Array<Int>>();
        for(pair in pairs){
            gobe.drawHsp(pair[0], 0);
            gobe.drawHsp(pair[1], 1);
        }
    }

    public function python_load(genespace_id:Int){

        python.load.call([genespace_id, gobe.base_name], python_load_callback);

        python_predict();
    }

    static function main() {
        flash.Lib.current.stage.scaleMode = flash.display.StageScaleMode.NO_SCALE;
        flash.Lib.current.stage.align     = flash.display.StageAlign.TOP_LEFT;
        haxe.Firebug.redirectTraces();
        var k:Int = 24;
        var v = new AnnoInput(flash.Lib.current, k, new Gobe());
    }
}


class ATextInput extends flash.text.TextField {
    public function new(mc:MovieClip, txt:String,x:Float, y:Float){
        super();
        this.x = x;
        this.y = y;
        this.text = txt + "\n\n\n\n\n\n";
        this.multiline = true;
        this.type = flash.text.TextFieldType.INPUT;
        this.autoSize = flash.text.TextFieldAutoSize.NONE;
        this.wordWrap = true;
        this.width = 340;
        this.border  = true;
        this.background = true;
        this.backgroundColor = 0xf6f6f6;

        this.defaultTextFormat = new flash.text.TextFormat("Arial", 16);
        mc.addChild(this);
    }
}
