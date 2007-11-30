import arctic.Arctic;
import arctic.ArcticBlock;
import arctic.ArcticView;
import arctic.ArcticDialogUi;

class Dialog {
    public var inputs:Array<Dynamic>;

    public static var answers:Hash<String>;

    static public function main() {
        flash.Lib.current.stage.scaleMode = flash.display.StageScaleMode.NO_SCALE;
        flash.Lib.current.stage.align     = flash.display.StageAlign.TOP_LEFT;
        haxe.Firebug.redirectTraces();
        new Dialog(flash.Lib.current);
    }

    public function new(parent : ArcticMovieClip) {
        var btn_sav = Background(0xcccccc, ArcticDialogUi.makeButton("<b>Save Genespace</b>", on_save_genespace, 17), 50.0, 20);
        var cbx_inprogress = Arctic.makeCheckbox(Arctic.makeText("IN PROGRESS", 14));
        answers = new Hash();

        var dupsq = TextInput("1", 15, 20, function(s){ if(s != "") {answers.set('dupsq',s); return true;} return false; }, null, 2, true, 0xffffff, true);
        var dupss = TextInput("1", 15, 20, function(s){ if(s != "") {answers.set('dupss',s); return true; } return false;}, null, 2, true, 0xffffff, true);

        inputs = [dupsq, dupss];
        var txt_dup_genes_q = ColumnStack([Arctic.makeText("PARENT + DUPS ON QUERY  ", 14), Frame(1, 0x000000, dupsq, 5, null, 2, 2) ]);
        var txt_dup_genes_s = ColumnStack([Arctic.makeText("PARENT + DUPS ON SUBJECT", 14), Frame(1, 0x000000, dupss, 5, null, 2, 2) ])  ;
        
        var dup_genes_title = Background(0xcccccc, ColumnStack([Filler, Arctic.makeText("<b>Duplicates</b>", 16, '#000000'), Filler]), 100.0, 10);
        var dup_genes = LineStack([dup_genes_title, LineStack([txt_dup_genes_q, txt_dup_genes_s])]);

        var header = ColumnStack([Filler, Arctic.makeText("<b>Gobe Lines</b>", 20, "#0000ff"), Filler ]);

        var keywords = ['BIGFOOT', 'APPRESSED', 'DUPLICATE HSPs', 'SPECIAL', 'NGCS NEARBY'];
        var kwd_cbxs = make_keyword_cbxs(keywords);
        var kwd_blocks = new Array<ArcticBlock>();
        for(c in kwd_cbxs){ kwd_blocks.push(c.block); }
        trace(kwd_blocks);


        var annotation_words = ['EXON NOT CALLED', 'FALSE EXON CALLED', 'SPLITS & FUSIONS', 'USED SB MODEL FOR MASK'];
        var anno_cbxs = make_keyword_cbxs(annotation_words);
        var anno_blocks = new Array<ArcticBlock>();
        for(cbx in anno_cbxs){ anno_blocks.push(cbx.block); }
        trace(anno_blocks);

        
        var tfmt = new flash.text.TextFormat("Arial", 15, 0x000000);

        var notes_textarea = [ 
               Background(0xcccccc, ColumnStack([Filler, Arctic.makeText("<b>NOTES</b>", 16, '#000000'), Filler]), 100.0, 10)
              ,TextInput("NOTES:", 150, 250, function(s){ return true; }, { multiline: true, wordWrap: true, defaultTextFormat: tfmt  }, 150*250, false, 0xffffff, true) 
          ];

         var kwds_title = Background(0xcccccc ,ColumnStack([Filler, Arctic.makeText("<b>Keywords</b>", 16, "#000000"), Filler]), 100.0, 10);
         var kwds = LineStack([kwds_title, LineStack(kwd_blocks)]);


        var view = LineStack([
                Background(0xcccccc, header, 50.0, 20)
                ,ColumnStack([ 
                          Frame(4, 0xbbbbbb ,kwds ,    10, null, 10, 10)
                        , Filler
                        , Frame(4, 0xbbbbbb, dup_genes, 10, null, 10, 10)
                        , Filler
                    ])
                , Filler
                , ColumnStack([
                     LineStack([
                            Frame(4, 0xbbbbbb,
                            LineStack([
                                Background(0xcccccc ,ColumnStack([Filler, Arctic.makeText("<b>Annotation Issues</b>", 16, "#000000"), Filler]), 100.0, 10)
                                ,LineStack( anno_blocks)
                            ]), 10, null, 10, 10)
                        , Filler    
                        , cbx_inprogress.block
                        , btn_sav

                     ]),
                        Filler
                    ,Frame(4, 0xbbbbbb, LineStack(notes_textarea), 10, null, 10, 10)
                    ])
                ]);
        arcticView = new ArcticView(view, parent);

        var root = arcticView.display(true);


    }


    public function make_keyword_cbxs(words:Array<String>) {
        var cbxs = new Array<arctic.ArcticState<Bool>>();
        for(word in words){
           var cbx = Arctic.makeCheckbox(Arctic.makeText(word, 14));
           cbxs.push( cbx);
        }
        return cbxs;
    }
    
    public function on_save_genespace(){
        trace(answers);
    }


    public var arcticView : ArcticView;
}
