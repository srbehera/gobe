#!/usr/bin/env perl

use strict;
use CGI;
use DBI;
use Data::Dumper;
use POSIX;
use JSON::Syck;
use File::Temp qw/ :mktemp /;
my $connstr = 'dbi:mysql:genomes:biocon:3306';



my $q = new CGI;
print "Content-Type: text/html\n\n";


my $tmpdir = "/opt/apache/CoGe/tmp/";

if($ENV{SERVER_NAME} !~ /(toxic|synteny)/){
    $tmpdir = "/opt/apache/CoGe/gobe/tmp/";
}



my $db  = "$tmpdir/" . $q->param('db') . ".sqlite";
unless (-r $db) {
    print STDERR $q->url(-query=>1),"\n";
    warn "database file $db does not exist or cannot be read!\n";
    exit;
}

my $dbh = DBI->connect("dbi:SQLite:dbname=$db") || die "cant connect to db";
my $sth;

if ($q->param('get_info')){
    my %result; 
    $sth = $dbh->prepare("SELECT iname, title FROM image_info order by id");
    my $sth2 = $dbh->prepare("select min(xmin), max(xmax), image_id from image_data where type='anchor' group by image_id order by image_id;");
    my $sth3 = $dbh->prepare("select * from image_info order by iname;");
    $sth->execute();
    $sth2->execute();
    $sth3->execute();
    my $i = 0;
    foreach my $title (@{$sth->fetchall_arrayref()}){
         $result{$title->[0]} =  {'title' => $title->[1], 'i' => $i++};
         my $anchors = $sth2->fetchrow_arrayref();
         my $info = $sth3->fetchrow_hashref();
         $result{$title->[0]}{'anchors'} = {'xmin' => $anchors->[0], 'xmax' => $anchors->[1], 'idx' => $anchors->[2]};
         $result{$title->[0]}{'extents'} = {'bpmin' => $info->{bpmin}, 'bpmax' => $info->{bpmax}, 'img_width' => $info->{px_width} };
    }

    #print STDERR Dumper %result;
    print JSON::Syck::Dump(\%result);
    exit();
}

if ($q->param('predict')){
    my $log = $db;
    $log =~ s/sqlite$/log/g;
    open(FH, "<", $log);
    my ($bl2seq, $eval1, $eval2);
    my $seen = 0;
    while (my $line = <FH>){
        last if $seen == 2;
        chomp $line;
        if ($line =~ /bl2seq/){ $bl2seq = $line; }
        elsif ($line =~ /cutoff/i){ 
            print STDERR $line . "\n";
            if ($seen == 0 ){ $eval1 = $line; $seen++; }
            elsif ($seen == 1){ $eval2 = $line; $seen++; }
        }
    }

    $bl2seq =~ s/.+(\/usr\/bin\/bl2seq.+)/$1/;
    $eval1  =~ s/.+\s([^\s]+)$/$1/;
    $eval2  =~ s/.+\s([^\s]+)$/$1/;
    chomp $bl2seq;

    # if necessary, fix for dev machine...
    if( $tmpdir =~ /^\/var\/www\//){ # TODO check -e (exists)
        $bl2seq =~ s/\/opt\/apache\/CoGe\/tmp\//$tmpdir\/tmpdir\//g;
    }
    $bl2seq =~ s/\-o\s[^\s]+//;
    # use tab-delimited output, and only the top strand
    $bl2seq .= " -D 1 -S 1 ";
    my $outfile = $log;
    $outfile =~ s/log$/blast/;
    print STDERR $outfile;
    `$bl2seq | grep -v '#' > $outfile`;
    # use tab-delimited output, and only the top strand
    my @res = `/usr/bin/python predict_cns.py "$outfile" $eval1 $eval2`;
    print STDERR "FROM PYTHON:" . scalar(@res)  . " pairs\n";
    close(FH);
    exit();
}

my $x    = $q->param('x');
my $y    = $q->param('y');
my $all  = $q->param('all') || 0;
my $img_id = $q->param('img');

my $statement;

my $x    = $q->param('x');
my $y    = $q->param('y');
my $all  = $q->param('all') || 0;
my $img_id = $q->param('img');

my $statement;
if($all){
    $sth = $dbh->prepare("SELECT distinct(image_track) FROM image_data WHERE ? BETWEEN ymin and ymax and image_id = ? order by abs(image_track) DESC");
    $sth->execute($y, $img_id);
    my ($track) = $sth->fetchrow_array();

    $statement = qq{ SELECT id, xmin, xmax, ymin, ymax, image_id, image_track, pair_id, color FROM image_data 
                    WHERE ( (image_track = ?) or (image_track = (? * -1) ) ) 
                    and image_id = ? and pair_id != -99 and type = "HSP" };
    $sth = $dbh->prepare($statement);

    $sth->execute($track, $track, $img_id);
}
else{
    $sth = $dbh->prepare("SELECT * FROM image_data WHERE ? + 3 > xmin AND ? - 3 < xmax AND ? BETWEEN ymin and ymax and image_id = ?");
    $sth->execute($x, $x, $y, $img_id);
}





my @results;
while( my $result = $sth->fetchrow_hashref() ){
    my $sth2 = $dbh->prepare("SELECT id, xmin, xmax, ymin, ymax, image_id, image_track, pair_id, color FROM image_data where id = ?");
    $sth2->execute( $result->{pair_id} );
    my $pair = $sth2->fetchrow_hashref();

    my $annotation = $result->{annotation};
    my $f1name = $result->{image_id}; # GEvo_rIKDAf4x_1.png -> 1
    my $f2name = $pair->{image_id};

    # TODO: clean this up. we should know if there's a pair or not.
    my @f1pts = map {floor  $result->{$_} + 0.5 } qw/xmin ymin xmax ymax/; push(@f1pts, $result->{'id'});
    my @f2pts = map { floor $pair->{$_} + 0.5 } qw/xmin ymin xmax ymax/;   push(@f2pts, $pair->{'id'});
    my $has_pair = 0;
    map { $has_pair += $_ } @f2pts;

    my $link = $result->{link};
    my $color = ($result->{color} ne 'NULL' && $result->{color} || $pair->{color}) ;
    $color =~ s/#/0x/;

    push(@results, {  link       => "/CoGe/$link"
                    , annotation => $annotation
                    , has_pair   => $has_pair
                    , color      => $color
                    , features   => {'key' . $f1name => \@f1pts,'key'. $f2name => \@f2pts}
                 });
    #print STDERR Dumper @results;
}
print JSON::Syck::Dump({resultset => \@results});
