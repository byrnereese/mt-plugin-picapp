package MT::Asset::PicApp;

use MT::Util qw( encode_html );
use strict;
use base qw( MT::Asset );

__PACKAGE__->install_properties( { class_type => 'picapp', } );
__PACKAGE__->install_meta( { columns => [ 
                                 'external_id',
                                 'external_author_id',
                                 'external_category_id',
                                 'original_title',
                                 'is_color',
                                 'is_horizontal',
                                 'is_vertical',
                                 'is_illustration',
                                 'is_panoramic',
                                 'photographer_name',
                                 'external_thumbnail_url',
                                 'external_image_url',
                                 'thumbnail_width',
                                 'thumbnail_height',
                                 'image_width',
                                 'image_height',
                                 'publish_url'
                                 ] 
                           } );

# External Properties
# authorId category imageTitle color description imageHeight imageWidth 
# horizontal illustration imageId panoramic photographerName thumbnailHeight 
# thumbnailWidth urlImageFullSize urlImageThumbnail vertical

sub class_label { MT->translate('PicApp Image'); }
sub class_label_plural { MT->translate('PicApp Images'); }
sub file_name { my $asset   = shift; return $asset->original_title; }
sub file_path { my $asset   = shift; return undef; }
sub on_upload { my $asset   = shift; my ($param) = @_; 1; }
sub has_thumbnail { 1; }

sub thumbnail_url {
    my $asset = shift;
    my (%param) = @_;

# Are thumbnail's resizable?
#    $param{'width'} = $param{'Width'} if ($param{'Width'});
#    $param{'height'} = $param{'Height'} if ($param{'Height'});

    return $asset->external_thumbnail_url;
}

sub as_html {
    my $asset   = shift;
    my ($param) = @_;
    my ($width,$height) = split("x",$param->{size});

# <a href="http://view.picapp.com/default.aspx?iid=6996139&term=" target="_blank"><img src="http://cdn.picapp.com/ftp/Images/a/e/6/6/Black_Cat_ad74.JPG?adImageId=8928300&imageId=6996139" width="380" height="412"  border="0" alt="Black Cat"/></a><script type="text/javascript" src="http://cdn.pis.picapp.com/IamProd/PicAppPIS/JavaScript/PisV4.js"></script>
# <a href="http://view.picapp.com/default.aspx?iid=681109&term=" target="_blank"><img src="http://cdn.picapp.com/ftp/Images/0/0/5/a/19.jpg?adImageId=8930104&imageId=681109" width="380" height="570"  border="0" alt="Barack Obama Visits Israel"/></a><script type="text/javascript" src="http://cdn.pis.picapp.com/IamProd/PicAppPIS/JavaScript/PisV4.js"></script>
# <a href="http://view.picapp.com/default.aspx?iid=681109&term=" target="_blank"><img src="http://cdn.picapp.com/ftp/Images/0/0/5/a/19.jpg?adImageId=8930104&imageId=681109" width="396" height="594"  border="0" alt="Barack Obama Visits Israel"/></a><script type="text/javascript" src="http://cdn.pis.picapp.com/IamProd/PicAppPIS/JavaScript/PisV4.js"></script>

    my $adImageId;
    if ($param->{'size'} eq 'small') {
        $adImageId = 8928300;
    } elsif ($param->{'size'} eq 'small') {
        $adImageId = 8930104;
    } else {
        $adImageId = 8930104;
    }

    my $wrap_style = '';
    if ( $param->{wrap_text} && $param->{align} ) {
        $wrap_style = 'class="mt-image-' . $param->{align} . '" ';
        if ( $param->{align} eq 'none' ) {
            $wrap_style .= q{style=""};
        }
        elsif ( $param->{align} eq 'left' ) {
            $wrap_style .= q{style="float: left; margin: 0 20px 20px 0;"};
        }
        elsif ( $param->{align} eq 'right' ) {
            $wrap_style .= q{style="float: right; margin: 0 0 20px 20px;"};
        }
        elsif ( $param->{align} eq 'center' ) {
            $wrap_style .= q{style="text-align: center; display: block; margin: 0 auto 20px;"};
        }
    }

    my $text = sprintf(
        '<a href="%s" target="_blank"><img %s src="%s?adImageId=%d&imageId=%d" width="%d" height="%d"  border="0" alt="%s" /></a><script type="text/javascript" src="http://cdn.pis.picapp.com/IamProd/PicAppPIS/JavaScript/PisV4.js"></script>',
        $asset->url,
        $wrap_style,
        $asset->external_image_url,
        $adImageId,
        $asset->external_id,
        $width,
        $height,
        encode_html($asset->original_title),
        );
    return $asset->enclose($text);
}

sub insert_options {
    my $asset = shift;
    my ($param) = @_;

    my $app   = MT->instance;
    my $perms = $app->{perms};
    my $blog  = $asset->blog or return;

    $param->{thumbnail}  = $asset->thumbnail_url;
    $param->{image_id}   = $asset->external_id;
    $param->{align_left} = 1;
    $param->{html_head}  = '<link rel="stylesheet" href="'.$app->static_path.'plugins/PicApp/app.css" type="text/css" />';

    return $app->build_page( '../plugins/PicApp/tmpl/dialog/asset_options.tmpl', $param );
}

1;
__END__

=head1 NAME

MT::Asset::PicApp

=head1 AUTHOR & COPYRIGHT

Please see the L<MT/"AUTHOR & COPYRIGHT"> for author, copyright, and
license information.

=cut
