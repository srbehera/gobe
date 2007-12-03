import fcomponentshx.FComponents;
import fcomponentshx.FLabel;
import fcomponentshx.FTextInput;
import fcomponentshx.FListView;
import fcomponentshx.FCheckButton;
import fcomponentshx.FButton;

import flash.display.MovieClip;
import flash.events.MouseEvent;
import flash.events.Event;


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
    var keywords_label   : FLabel;
    static var keywords_cbxs    : FListView;
    
    static var annos:Array<String> = ['EXON NOT CALLED', 'FALSE EXON CALLED', 'SPLITS AND FUSIONS', 'USED SB MODEL FOR MASK'];
    var anno_label       : FLabel;
    static var anno_cbxs        : FListView;

    var dups_label       : FLabel;
    var dups_cbxs        : FListView;

    var notes_label      : FLabel;
    //var notes_txt        : FTextInput;
    static var notes_txt        : flash.text.TextField;

    var in_progress_label: FLabel;
    static var in_progress      : FCheckButton;

    var save_button      : FButton;

    static var cnx:haxe.remoting.AsyncConnection = haxe.remoting.AsyncConnection.amfConnect( '/gobe/trunk/flash/dialog/service.wsgi' );


    function new (mc:MovieClip, genespace_id:Int) {
        super();


        // FComponents.FTextInputGFXRect = new flash.geom.Rectangle ( 3, 3, 58, 10 );
        // Add your own CSS style:
        var css = FComponents.css;
        css.setStyle( "header", {
                            fontFamily  : "Arial",
                            fontStyle   : "italic",
                            fontSize    : 15,
                            display     : "inline"
                        });
        css.setStyle( "title", {
                            fontFamily  : "Arial",
                            fontStyle   : "italic",
                            fontSize    : 20,
                            display     : "inline"
                        });
        css.setStyle( "p", {
                            color       : "#333333",
                            fontWeight  : "bold",
                            fontFamily  : "Arial",
                            fontSize    : 10
                        });

        var x:Float = 0.0;
        keywords_label = new FLabel( mc, "<header>Keywords</header>", { x: x, y: null } );
        keywords_cbxs  = new FListView( mc, keywords, keywords, { x: x, y : 20.0 }, null, true, true );

        x = 150.0; 
        anno_label = new FLabel(mc, "<header>Annotation Issues</header>", { x: x, y: null } );
        anno_cbxs  = new FListView(mc, annos, annos, { x : x, y : 20.0 }, null, true, true );

        x = 0.0; 
        notes_label = new FLabel(mc, "<header>Notes</header>", { x: x, y: 115.0 } );
        notes_txt = new ATextInput(mc, "", x, 135.0);

        var y:Float = 250.0;
        in_progress = new FCheckButton(mc, "IN PROGRESS", { x:x, y: y});
        save_button = new FButton(mc, "<header>Save</header>", {x: 150.0 , y: y}, cnx_save);
                        
        cnx_load(genespace_id);
    }

    public function cnx_save(e: MouseEvent){
        cnx.save.call([{
             keywords:keywords_cbxs.selectedIndexes
             ,annos:anno_cbxs.selectedIndexes
             ,notes:notes_txt.text
             ,in_progress: in_progress.checked}
          ]
          , function(s){trace(s);}
       );
    }

    private function cnx_load(genespace_id:Int){
        trace(genespace_id);
        cnx.load.call([genespace_id], function(s:Dynamic){  
            trace(Reflect.field(s, 'annos'));
            anno_cbxs.setSelectedIndexes(Reflect.field(s, 'annos'));
            keywords_cbxs.setSelectedIndexes(Reflect.field(s, 'keywords'));
            notes_txt.text = Reflect.field(s, 'notes');
            in_progress.setChecked(Reflect.field(s,'in_progress'));
        });
    }


    static function main() {
        flash.Lib.current.stage.scaleMode = flash.display.StageScaleMode.NO_SCALE;
        flash.Lib.current.stage.align     = flash.display.StageAlign.TOP_LEFT;
        haxe.Firebug.redirectTraces();
        var k:Int = 24;
        var v = new AnnoInput(flash.Lib.current, k);
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
