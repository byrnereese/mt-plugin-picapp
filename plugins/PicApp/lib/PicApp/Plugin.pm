package PicApp::Plugin;

use strict;
use Net::PicApp;
use MT::Util qw( decode_url encode_url );

sub plugin {
    return MT->component('PicApp');
}

sub id { 'picapp' }

sub uses_picapp {
    my $blog = MT->instance->blog;
    return 0 if !$blog;
    # If the user has forcibly enabled custom css, then return true.
    my $apikey = plugin()->get_config_value('picapp_api_key','blog:'.$blog->id);
    return 1 if $apikey;
    return 0;
}

sub find_results {
    my $app = shift;

    my $q = $app->{query};
    my $blog = $app->blog;

    my ($keywords,$category,$subcategory);
    if ($q->param('kw')) {
        $keywords    = $q->param('kw');
        $category    = $q->param('category') || 'Editorial';
        $subcategory = $q->param('subcategory');
    } else {
        my $c = $app->cookie_val('mt_picapp') || '';
        ($keywords,$category,$subcategory) = ($c =~ /^kw=([^\&]*)&c=([^\&]*)&s=(.*)$/) if $c;
        $keywords ||= '*';
        $keywords = decode_url($keywords);
        $category ||= 'Editorial';
    }

    my $blog_id     = $q->param('blog_id');
    my $page        = $q->param('page') || 1;
    my $format      = $q->param('format') || 1;

    my %cookie1 = (
        -name  => 'mt_picapp',
        -value => "kw=".encode_url($keywords)."&c=".$category."&s=".$subcategory,
        );
    $app->bake_cookie(%cookie1);

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
        category => $category,
        subcategory => $subcategory,
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

    my @i_array = $response->images();
    my @images;
    foreach my $i (@i_array) {
        push @images, {
            id          => $i->imageId,
            title       => $i->imageTitle,
            description => $i->description,
            thumbnail   => $i->urlImageThumbnail,
        };
    }

    if ($format eq 'json') {
        return MT::Util::to_json({ 
            images => \@images,
            page_count => int($response->total_records / 20),
            url_queried => $response->url_queried,
        });
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
    my $id = $q->param('selected');

    my $plugin = MT->component('PicApp');
    my $apikey = $plugin->get_config_value('picapp_api_key','blog:'.$app->blog->id);

    my $url = MT->config->PicAppServerURL;
    my $cache_path = MT->config->PicAppCachePath;

    my $cache;
    if ($cache_path ne '') {
        require Cache::File;
        $cache = Cache::File->new( 
            cache_root        => $cache_path,
            default_expires   => '10 days',
            );
    }
    my $picapp = Net::PicApp->new({
        apikey => $apikey,
        url => $url,
        cache => $cache
    });
    my $response = $picapp->get_image_details($id);
    if ($response->is_error) {
        MT->log({
            blog_id => $app->blog->id,
            message => "There was an error interfacing with PicApp: " . $response->error_message
                });
    }
    my $image = $response->images();

    my $asset = MT->model('asset.picapp')->new;
    # TODO - look for the asset by external asset_id to see if it has already been imported

    $asset->blog_id($q->param('blog_id'));
    $asset->label( $image->imageTitle );
    $asset->description( $image->description );

    $asset->url( $image->publishPageLink );
    $asset->external_image_url( $image->urlImageFullSize );
    $asset->image_height( $image->imageHeight );
    $asset->image_width( $image->imageWidth );

    $asset->external_id( $image->imageId );
    $asset->external_author_id( $image->authorId );
    $asset->external_category_id( $image->category );
    $asset->original_title( $image->imageTitle );
    $asset->is_color( $image->color eq 'True' ? 1 : 0 );
    $asset->is_horizontal( $image->horizontal eq 'True' ? 1 : 0 );
    $asset->is_vertical( $image->vertical eq 'True' ? 1 : 0 );
    $asset->is_illustration( $image->illustration eq 'True' ? 1 : 0 );
    $asset->is_panoramic( $image->panoramic eq 'True' ? 1 : 0 );
    $asset->photographer_name( $image->photographerName );
    $asset->external_thumbnail_url( $image->urlImageThumbnail );
    $asset->thumbnail_width( $image->thumbnailWidth );
    $asset->thumbnail_height( $image->thumbnailHeight );

    $asset->created_by( $app->user->id );

    my $original = $asset->clone;
    $asset->save;

    $app->run_callbacks( 'cms_post_save.asset', $app, $asset, $original );

    return $app->complete_insert( 
        asset       => $asset,
        description => $asset->description,
        thumbnail   => $asset->thumbnail_url,
        keywords    => $app->{query}->param('keywords'),
        is_picapp   => 1,
    );
}

1;
