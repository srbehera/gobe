import arctic.Arctic;
import arctic.ArcticBlock;
import arctic.ArcticView;
import arctic.ArcticDialogUi;

import flash.net.URLLoader;
import flash.display.Loader;
import flash.net.URLRequest;

class Dialog {
    public var info_body:ArcticBlock;
    public var anno_body:ArcticBlock;
    public var body:MutableBlock;

    public static var answers:Hash<String>; // all the answers from the anno tab
    public static var notes_txt:ArcticBlock;
    public static var anno_txt:String; // all the html for the current view

    static public function main() {
        flash.Lib.current.stage.scaleMode = flash.display.StageScaleMode.NO_SCALE;
        flash.Lib.current.stage.align     = flash.display.StageAlign.TOP_LEFT;
        haxe.Firebug.redirectTraces();
        new Dialog(flash.Lib.current);
    }


    public function new(parent : ArcticMovieClip) {
        answers = new Hash();
        answers.set('NOTES', 'NOTES:');
        answers.set('dupsq', '1');
        answers.set('dupss', '1');


        anno_txt = "<p><b>lots of txt</b></p><p>sequence:actcctcgatttgactacgtatcgatgactgatgcatgatgaacccaccat</p><p>annotation</p>";



        var btn_sav = Background(0xcccccc, ArcticDialogUi.makeButton("<b>Save Genespace</b>", on_save_genespace, 17), 50.0, 20);
        var cbx_inprogress = Arctic.makeCheckbox(Arctic.makeText("IN PROGRESS", 14), function(sel){
                answers.set('IN PROGRESS', 'ON'); // do it this way so we dont have to check bfore removing
                if(!sel) { answers.remove('IN PROGRESS'); }
        });

        var dupsq = TextInput("", 15, 20, function(s){ if(s != "") {answers.set('dupsq',s); } return true; }, null, 2, true, 0xffffff, true, function(fn){
            fn(answers.get('dupsq'), true);
        });
        var dupss = TextInput("", 15, 20, function(s){ if(s != "") {answers.set('dupss',s); } return true; }, null, 2, true, 0xffffff, true, function(fn){ 
            fn(answers.get('dupss'), true); 
        });

        var txt_dup_genes_q = ColumnStack([Arctic.makeText("PARENT + DUPS ON QUERY  ", 14), Frame(1, 0x000000, dupsq, 5, null, 2, 2) ]);
        var txt_dup_genes_s = ColumnStack([Arctic.makeText("PARENT + DUPS ON SUBJECT", 14), Frame(1, 0x000000, dupss, 5, null, 2, 2) ])  ;
        
        var dup_genes_title = Background(0xcccccc, ColumnStack([Filler, Arctic.makeText("<b>Duplicates</b>", 16, '#000000'), Filler]), 100.0, 10);
        var dup_genes = LineStack([dup_genes_title, LineStack([txt_dup_genes_q, txt_dup_genes_s])]);

        var anno_button = ArcticDialogUi.makeButton("INFO", function(){}, 15);
        var info_button = ArcticDialogUi.makeButton("ANNO", function(){}, 15);

        var button_state = ToggleButton(anno_button, info_button, false, button_state_click, function(a){});


        //var header = ColumnStack([anno_button, info_button, Filler, Arctic.makeText("<b>Gobe Lines</b>", 20, "#0000ff"), Filler ]);
        var header = ColumnStack([button_state, Filler, Arctic.makeText("<b>Gobe Lines</b>", 20, "#0000ff"), Filler ]);


        var keywords = ['BIGFOOT', 'APPRESSED', 'DUPLICATE HSPs', 'SPECIAL', 'NGCS NEARBY'];
        var kwd_cbxs = make_keyword_cbxs(keywords);
        var kwd_blocks = new Array<ArcticBlock>();
        for(c in kwd_cbxs){ kwd_blocks.push(c.block); }
        trace(kwd_blocks);


        var annotation_words = ['EXON NOT CALLED', 'FALSE EXON CALLED', 'SPLITS AND FUSIONS', 'USED SB MODEL FOR MASK'];
        var anno_cbxs = make_keyword_cbxs(annotation_words);
        var anno_blocks = new Array<ArcticBlock>();
        for(cbx in anno_cbxs){ anno_blocks.push(cbx.block); }
        trace(anno_blocks);

        var tfmt = new flash.text.TextFormat("Arial", 15, 0x000000);

        notes_txt = TextInput("", 150, 250, function(s){ if(s != ""){ answers.set('NOTES', s);} return true; }, { multiline: true, wordWrap: true, defaultTextFormat: tfmt  }, 150*250, false, 0xffffff, true, function(fn) { 
                        fn(answers.get('NOTES'), false);
                     });
        var notes_textarea = [ 
               Background(0xcccccc, ColumnStack([Filler, Arctic.makeText("<b>NOTES</b>", 16, '#000000'), Filler]), 100.0, 10)
              , notes_txt
          ];

         var kwds_title = Background(0xcccccc ,ColumnStack([Filler, Arctic.makeText("<b>Keywords</b>", 16, "#000000"), Filler]), 100.0, 10);
         var kwds = LineStack([kwds_title, LineStack(kwd_blocks)]);

         anno_body = LineStack([ColumnStack([ 
                          Border(1, 1, Frame(4, 0xbbbbbb ,kwds ,    10, null, 10, 10))
                        , Border(1, 1, Frame(4, 0xbbbbbb, dup_genes, 10, null, 10, 10))
                    ])
                , ColumnStack([
                     LineStack([
                            Border(1, 1, Frame(4, 0xbbbbbb,
                            LineStack([
                                Background(0xcccccc ,ColumnStack([Filler, Arctic.makeText("<b>Annotation Issues</b>", 16, "#000000"), Filler]), 100.0, 10)
                                ,LineStack( anno_blocks)
                            ]), 10, null, 10, 10))
                        , Filler    
                        , cbx_inprogress.block
                        , btn_sav

                     ])
                    ,Frame(4, 0xbbbbbb, LineStack(notes_textarea), 10, null, 10, 10)
                    ])
                ]);

        info_body = LineStack([
            Arctic.makeText(anno_txt, 25)
        ]);

        body = new MutableBlock(info_body);
        var view = LineStack([
                Background(0xcccccc, header, 50.0, 20)
                ,
                 Mutable(body)
                ]);
        arcticView = new ArcticView(view, parent);

        var root = arcticView.display(false);


    }


    public function make_keyword_cbxs(words:Array<String>) {
        var cbxs = new Array<arctic.ArcticState<Bool>>();
        for(word in words){
           var cbx = Arctic.makeCheckbox(Arctic.makeText(word, 14), function(sel){ 
                       answers.set(word, 'ON');
                       if(!sel) { answers.remove(word); }
           });
           cbxs.push( cbx);
        }
        return cbxs;
    }

    public function button_state_click(is_anno){
        if(is_anno){ 
            if(body.block == anno_body){ return; }
            body.block = anno_body;
        }
        else { 
            if(body.block == info_body){ return; }
            body.block = info_body;
        }
        arcticView.refresh(true);
    }
    
    public function on_save_genespace(){
        var query_str:String = '';
        for(k in answers.keys()){
            query_str += '&' + k + '=' + answers.get(k);
        }
        var qloader = new Loader();
        var base_url:String = '/gobe/trunk/';
        //qloader.contentLoaderInfo.addEventListener(flash.events.Event.COMPLETE, function(e:flash.events.Event){ trace('done'); });
        trace(query_str);
        var url = base_url + 'query.pl?' + query_str;
        var ctx = new flash.system.LoaderContext(false, flash.system.ApplicationDomain.currentDomain);
        //qloader.load(new URLRequest(url), ctx);
        trace(answers);


    }


    public var arcticView : ArcticView;
}
