#!/usr/bin/perl
use strict;
use warnings;
use Carp;
use English qw ( -no_match_vars );
use Readonly;
use XML::LibXML;
use autodie qw(open close);
use File::Find;
use File::Slurp;

Readonly my $SOURCE_DIR => 'htdocs/sgml-lib';
Readonly my $CATALOG_XML => 'catalog.xml';
Readonly my $DEST_DIR => 'usr/share/xml/w3c-sgml-lib/schema/dtd';

Readonly my $LEGACY_DTD_DIR => 'usr/share/xml/xhtml/schema/dtd';
Readonly my $LEGACY_ENT_DIR => 'usr/share/xml/entities/xhtml';
Readonly my $LEGACY_SRC_DIR => 'debian/legacy';
Readonly my $LEGACY_MATCH_RE => qr{\A[\w\-]+\.(ent|dcl|dtd|mod)\z}xms;
Readonly my $LEGACY_MATCH_ENT_RE => qr{\A[\w\-\/]+\.ent\z}xms;
Readonly my $LEGACY_MATCH_DCL_RE => qr{\A[\w\-\.\/]+\.dcl\z}xms;
Readonly my $PUBLIC_ID_RE => qr{^\s*PUBLIC\s+\"([\-\/\w\.\s]+)\"\s*$}xms;

sanity_check();
generate_debian_xmlcatalogs();
my %legacy_src = collect_legacy_src();
my %public_ids = extract_public_ids(keys %legacy_src);

exit(0);

sub generate_debian_xmlcatalogs {

    open(my $fh, '>', 'debian/xmlcatalogs');
    print {$fh} "local;$SOURCE_DIR/$CATALOG_XML;/$DEST_DIR/$CATALOG_XML\n";

    # Set up XML processing machinery
    my $parser = XML::LibXML->new();
    my $doc = $parser->parse_file("$SOURCE_DIR/$CATALOG_XML");
    my $xpc = XML::LibXML::XPathContext->new();
    $xpc->registerNs('x', $doc->getDocumentElement->getNamespaces->getValue);

    # Write new catalog.xml and populate memory structures
    my @nodes_with_uri = $xpc->findnodes('//*[@uri]', $doc);
    foreach my $node (@nodes_with_uri) {
        my $uri = $node->getAttribute('uri');
        my $name = $node->nodeName;
        my $id = ($name eq 'public') ? $node->getAttribute('publicId')
            : ($name eq 'system') ? $node->getAttribute('systemId')
            : croak "unrecognized elemeny: $name";

        print {$fh} "root;$name;$id\n";
        print {$fh} "package;$name;$id;/$DEST_DIR/$CATALOG_XML\n";
        print {$fh} "\n";
    }

    close $fh;
    return;
}

sub collect_legacy_src {
    my %results;
    find(sub {
            return if $_ !~ $LEGACY_MATCH_RE;
            my $dest = $File::Find::name;
            if ($dest =~ m{\A$LEGACY_MATCH_ENT_RE}xms) {
                $dest =~ s{$LEGACY_SRC_DIR/basic}{$LEGACY_ENT_DIR}xms;
            }
            else {
                $dest =~  s{$LEGACY_SRC_DIR}{$LEGACY_DTD_DIR}xms;
            }
            $results{$File::Find::name} = $dest;
            return;
        },
        $LEGACY_SRC_DIR);
    return %results;
}

sub extract_public_ids {
    my @src_files = @_;
    my %results;
    foreach my $file (@src_files) {
        my $doc = read_file($file);
        if ($file =~ $LEGACY_MATCH_DCL_RE) {
            $results{$file} = undef;
        }
        elsif ($doc =~ $PUBLIC_ID_RE) {
            $results{$file} = $1;
        }
        else {
            croak "Could not find public id for $file";
        }
    }
    return %results;
}

sub sanity_check {
    foreach my $file ('debian', $SOURCE_DIR, $LEGACY_SRC_DIR) {
        if (! -d $file) {
            croak "Cannot find directory $file";
        }
    }
    foreach my $file ($CATALOG_XML) {
        if (! -r "$SOURCE_DIR/$file") {
            croak "Cannot read $file";
        }
    }
    return;
}

# Copyright 2010-2012, Nicholas Bamber, Artistic License

