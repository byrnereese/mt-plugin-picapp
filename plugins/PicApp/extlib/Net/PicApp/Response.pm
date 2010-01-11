package Net::PicApp::Response;

use strict;
use Net::PicApp::Image;

# use 'our' on v5.6.0
use vars qw(@EXPORT_OK %EXPORT_TAGS);

use base qw(Class::Accessor);
Net::PicApp::Response->mk_accessors(
    qw( total_records record_count error_message rss_link url_queried ));

# We are exporting functions
use base qw/Exporter/;

sub init {
    my $self = shift;
    my ($xml) = @_;
    if ($self->url_queried =~ /getimagedetails/i) {
        $self->total_records( 1 );
        my $info = $xml->{ImageInfo};
        my @infos;
        if (ref $info eq 'ARRAY') {
            @infos = @{ $info };
        } else {
            @infos = ( $info );
        }
        my @images;
        foreach (@infos) {
            push @images, Net::PicApp::Image->new($_);
        }
        $self->images( @images );
    } else {
        # Its a search
        $self->total_records( $xml->{totalRecords} );
        $self->rss_link( $xml->{rssLink} );
        my @infos = @{ $xml->{ImageInfo} };
        my @images;
        foreach (@infos) {
            push @images, Net::PicApp::Image->new($_);
        }
        $self->images( @images );
        $self->record_count( $#infos + 1 );
    }
    return $self;
}

sub images {
    my $self = shift;
    if ($_[0]) {
        $self->{images} = \@_;
    }
    my @a = $self->{images} ? @{$self->{images}} : ();
    return wantarray ? @a : $a[0];
}

sub is_success {
    return ( $_[0]->error_message ? 0 : 1 );
}

sub is_error {
    return ( $_[0]->error_message ? 1 : 0 );
}

1;
