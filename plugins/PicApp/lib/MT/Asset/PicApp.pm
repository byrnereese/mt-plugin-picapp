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

    my $app = MT->instance;
    $param->{enclose} = 1 if ($app->param('edit_field') =~ /^customfield/ || MT->version_number < 4.3);
    $param->{enclose} = 0 unless exists $param->{enclose};

    my ($width,$height) = split("x",$param->{size});

    require Net::PicApp;
    my $plugin = MT->component('PicApp');
    my $apikey = $plugin->get_config_value('picapp_api_key','blog:'.$asset->blog_id);
    my $url = MT->config->PicAppServerURL;

    my $picapp = Net::PicApp->new({
        apikey => $apikey,
        url => $url,
    });
    my $response = $picapp->publish($asset->external_id, $app->param('keywords'), $app->user->email, { 
        size => ($width == 234 ? 1 : ($width == 350 ? 2 : 3))
    });

    if ($response->is_error) {
        MT->log({
            blog_id => $app->blog->id,
            message => "There was an error interfacing with PicApp: " . $response->error_message
                });
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
        '<div class="picapp-image" %s>%s</div>',
        $wrap_style,
        $response->image_tag
        );

    print STDERR "enclose? " . ($param->{enclose} ? "yes" : "no") . "\n";
    return $param->{enclose} ? $asset->enclose($text) : $text;
}

sub insert_options {
    my $asset = shift;
    my ($param) = @_;

    my $app   = MT->instance;
    my $perms = $app->{perms};
    my $blog  = $asset->blog or return;

    $param->{thumbnail}  = $asset->thumbnail_url;
    $param->{keywords}   = $app->{query}->param('keywords');
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
