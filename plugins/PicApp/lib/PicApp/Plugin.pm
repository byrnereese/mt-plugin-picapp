package PicApp::Plugin;

use strict;
use Net::PicApp;

sub find {
    my $app = shift;
    my $q = $app->{query};
    my $blog = $app->blog;
    my $tmpl = $app->load_tmpl('dialog/find.tmpl');
    $tmpl->param(blog_id      => $blog->id);
    return $app->build_page($tmpl);
}

sub find_results {
    my $app = shift;

    my $q = $app->{query};
    my $blog = $app->blog;

    my $blog_id  = $q->param('blog_id');
    my $keywords = $q->param('kw');
    my $category = $q->param('category') || 1;
    my $page     = $q->param('page') || 1;
    my $format   = $q->param('format') || 1;

    my $limit = 10;
    my $offset = $limit * ($page - 1);

    my $plugin = MT->component('PicApp');
    my $apikey = $plugin->get_config_value('picapp_api_key','blog:'.$app->blog->id);

    my $url = MT->config->PicAppServerURL;
    my $cache_path = MT->config->PicAppCachePath;

    my $cache;
    if ($cache_path ne '') {
        require Cache::File;
        $cache = Cache::File->new( 
            cache_root        => $cache_path,
            default_expires   => '15 min',
            );
    }

    my $picapp = Net::PicApp->new({
        apikey => $apikey,
        url => $url,
        cache => $cache
    });
    my $response = $picapp->search($keywords, { 
        subcategory => $category,
        with_thumbnails => 1,
        total_records => 20,
        page => $page
    });

    if ($response->is_error) {
        MT->log({
            blog_id => $app->blog->id,
            message => "There was an error interfacing with PicApp: " . $response->error_message
                });
    }

    my @images;
    foreach my $i (@{$response->images}) {
        push @images, {
            id          => $i->imageId,
            title       => $i->imageTitle,
            description => $i->description,
            thumbnail   => $i->urlImageThumbnail,
        };
    }

    if ($format eq 'json') {
        return MT::Util::to_json( { images => \@images } );
    } else {
        my $tmpl = $app->load_tmpl('dialog/find_results.tmpl');
        $tmpl->param(return_args => "__mode=find&blog_id=".$blog->id."&kw=".$keywords);
        $tmpl->param(total_results => $response->total_records);
        $tmpl->param(page_count => int($response->total_records / 20));
        $tmpl->param(url_queried => $response->url_queried);
        $tmpl->param(blog_id => $blog->id);
        $tmpl->param(blog_name => $blog->name);
        $tmpl->param(images_loop => \@images);
        $tmpl->param(keywords => $keywords);
        $tmpl->param(category => $category);
        return $app->build_page($tmpl);
    }
}

sub asset_options {
    my $app = shift;
    my $q = $app->{query};
    my $blog = $app->blog;
    my $vid = $q->param('selected');

#    my $xml = _get_youtube_feed( video => $vid );
#    my $item = XMLin($xml);
#    use Data::Dumper;
#    my $title = $item->{title}->{content};
#    require MT::Asset::YouTube;
    my $asset = MT->model('asset.picapp')->new;
    $asset->blog_id($q->param('blog_id'));
#    $asset->video_id($vid);
#    $asset->label($title);
#    $asset->description($item->{'media:group'}->{'media:description'}->{'content'});
#    $asset->url($item->{'media:group'}->{'media:player'}->{url});
#    $asset->yt_thumbnail_url($item->{'media:group'}->{'media:thumbnail'}->[0]->{url});
#    $asset->yt_thumbnail_width($item->{'media:group'}->{'media:thumbnail'}->[0]->{width});
#    $asset->yt_thumbnail_height($item->{'media:group'}->{'media:thumbnail'}->[0]->{height});
#    $asset->created_by( $app->user->id );
#    $asset->original_title($title);

    my $original = $asset->clone;
    $asset->save;
    $app->run_callbacks( 'cms_post_save.asset', $app, $asset, $original );

    return $app->complete_insert( 
        asset       => $asset,
        description => $asset->description,
        thumbnail   => $asset->thumbnail_url,
        is_picapp   => 1,
    );
}

1;
