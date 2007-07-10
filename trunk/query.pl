#!/usr/bin/env perl

use strict;
use CGI;
use DBI;
use Data::Dumper;
use POSIX;
use JSON::Syck;

my $q = new CGI;
print "Content-Type: text/html\n\n";

#UNCOMMENT FOR TOXIC.
#$tmpdir = "/opt/apache/CoGe/";
my $tmpdir = "/var/www/gobe/";
if($ENV{SERVER_NAME} =~ /(toxic|synteny)/){
    $tmpdir = "/opt/apache/CoGe/";
}


my $db  = "$tmpdir/" . $q->param('db');
my $dbh = DBI->connect("dbi:SQLite:dbname=$db") || die "cant connect to db";
my $sth;

if ($q->param('image_names')){
    $sth = $dbh->prepare("SELECT title FROM image_info order by id");
    $sth->execute();
    print JSON::Syck::Dump([map{$_->[0]} @{ $sth->fetchall_arrayref()}]);
    exit;
}

my $x    = $q->param('x');
my $y    = $q->param('y');
my $all  = $q->param('all') || 0;
my ($img)= $q->param('img') =~ /.+\/([^\/]+)/;

if($all){
    $sth = $dbh->prepare("SELECT * FROM image_data WHERE ? BETWEEN ymin and ymax and image = ?");
    $sth = $dbh->prepare("SELECT * FROM image_data WHERE image_track =
    (SELECT image_track from image_data WHERE ? BETWEEN ymin and ymax
    and image = ?) and image = ?");
    $sth->execute($y, $img, $img);
}
else{
    $sth = $dbh->prepare("SELECT * FROM image_data WHERE ? + 2 > xmin AND ? - 2 < xmax AND ? BETWEEN ymin and ymax and image = ?");
    $sth->execute($x, $x, $y, $img);
}


my @results;
while( my $result = $sth->fetchrow_hashref() ){
    #if(! $result){ print 'false'; exit(0); }
    #print STDERR Dumper $result;
    my $annotation = $result->{annotation};
    my $sth2 = $dbh->prepare("SELECT * FROM image_data where id = ?");
    $sth2->execute($result->{pair_id} );
    my $pair = $sth2->fetchrow_hashref();
    #print STDERR Dumper $pair;

    my ($f1name) = $result->{image} =~ /_(\d+)\.png/;
    my ($f2name) = $pair->{image} =~ /_(\d)\.png/;
    my @f1pts = map {floor  $result->{$_} + 0.5 } qw/xmin ymin xmax ymax/;
    my @f2pts = map { floor $pair->{$_} + 0.5 } qw/xmin ymin xmax ymax/;
    #my $f2pts = "[700, 20, 900, 80]";
    my $link = $result->{link};
    my $color = ($result->{color} ne 'NULL' && $result->{color} || $pair->{color}) ;
    $color =~ s/#/0x/;
    $annotation =~ s/=small/="small"/g;
    $annotation =~ s/<br>/<br\/>/g;
    print STDERR $annotation . "\n\n";
    push(@results, {  link       => "/CoGe/$link"
                    , annotation => $annotation
                    # SOMETIMES one of them is NULL.
                    , color      => $color
                    , features   => {$f1name => \@f1pts,$f2name => \@f2pts}
                 });
}
my $resultset = {resultset => \@results};
print JSON::Syck::Dump($resultset);
