#!/usr/bin/env perl

use strict;
use CGI;
use DBI;
use Data::Dumper;
use POSIX;
use JSON::Syck;

my $q = new CGI;
print "Content-Type: text/html\n\n";

my $tmpdir;
if($ENV{SERVER_NAME} =~ /(toxic|synteny)/){
    $tmpdir = "/opt/apache/CoGe/";
}
else {
    $tmpdir = "/var/www/gobe/";
}



my $db  = "$tmpdir/" . $q->param('db');
unless (-r $db) {
    print STDERR $q->url(-query=>1),"\n";
    warn "database file $db does not exist or cannot be read!\n";
    exit;
}

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

my $statement;
if($all){
    $sth = $dbh->prepare("SELECT distinct(image_track) FROM image_data WHERE ? BETWEEN ymin and ymax and image = ? order by abs(image_track) DESC");
    $sth->execute($y, $img);
    my ($track) = $sth->fetchrow_array();

    $statement = qq{ SELECT name, xmin, xmax, ymin, ymax, image, image_track, pair_id, color FROM image_data 
    WHERE ( (image_track = ?) or (image_track = (? * -1) ) ) and image = ? and pair_id != -99 and type = "HSP" };
    $sth = $dbh->prepare($statement);

    $sth->execute($track, $track, $img);
}
else{
    $sth = $dbh->prepare("SELECT * FROM image_data WHERE ? + 2 > xmin AND ? - 2 < xmax AND ? BETWEEN ymin and ymax and image = ?");
    #$statement = "SELECT * FROM image_data WHERE $x + 2 > xmin AND $x - 2 < xmax AND $y BETWEEN ymin and ymax and image = \"$img\"";
    $sth->execute($x, $x, $y, $img);
}



my @results;
while( my $result = $sth->fetchrow_hashref() ){
    my $sth2 = $dbh->prepare("SELECT * FROM image_data where id = ?");
    $sth2->execute( $result->{pair_id} );
    my $pair = $sth2->fetchrow_hashref();

    my $annotation = $result->{annotation};
    my ($f1name) = $result->{image} =~ /_(\d+)\.png/; # GEvo_rIKDAf4x_1.png -> 1
    my ($f2name) = $pair->{image} =~ /_(\d+)\.png/;

    # TODO: clean this up. we should know if there's a pair or not.
    my @f1pts = map {floor  $result->{$_} + 0.5 } qw/xmin ymin xmax ymax/;
    my $sum = 0; map { $sum += $_ } @f1pts;
    if(!$sum) { next; }
    my @f2pts = map { floor $pair->{$_} + 0.5 } qw/xmin ymin xmax ymax/;
    $sum = 0; map { $sum += $_ } @f2pts;

    my $link = $result->{link};
    my $color = ($result->{color} ne 'NULL' && $result->{color} || $pair->{color}) ;
    $color =~ s/#/0x/;

    push(@results, {  link       => "/CoGe/$link"
                    , annotation => $annotation
                    , has_pair   => $sum
                    , color      => $color
                    , features   => {'key' . $f1name => \@f1pts,'key'. $f2name => \@f2pts}
                 });
}
#print STDERR Dumper @results;
print JSON::Syck::Dump({resultset => \@results});
