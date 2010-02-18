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
    my $apikey = MT->config->PicAppAPIKey;
    return 1 if $apikey;
    return 0;
}

sub pre_save {
    my ( $cb, $app, $obj, $orig ) = @_;
#    require MT::App;
#    my $app = MT::App->instance;
    my $ref = ref $app;
    if ($ref eq "MT::App::CMS" && $app->mode eq 'save_entry') {
        $obj->{column_values}->{text} =~ s{<!--//PICAPPSCRIPTTAG-->}{<script type="text/javascript" src="http://cdn.pis.picapp.com/IamProd/PicAppPIS/JavaScript/PisV4.js"></script>}gm;
        $obj->{column_values}->{text_more} =~ s{<!--//PICAPPSCRIPTTAG-->}{<script type="text/javascript" src="http://cdn.pis.picapp.com/IamProd/PicAppPIS/JavaScript/PisV4.js"></script>}gm;
    }
    return 1;
}

sub xfrm_edit {
    my ($cb, $app, $tmpl) = @_;
    return 1 unless uses_picapp();
    my $slug1 = <<END_TMPL;
<link rel="stylesheet" href="<mt:StaticWebPath>plugins/PicApp/app.css" type="text/css" />
END_TMPL
    $$tmpl =~ s{(<mt:setvarblock name="html_head" append="1">)}{$1$slug1}msg;
}

sub xfrm_editor {
    my ($cb, $app, $tmpl) = @_;
    return 1 unless uses_picapp();
    my $slug2 = <<END_TMPL;
<a href="javascript: void 0;" title="<__trans phrase="Insert PicApp Image" escape="html">" mt:command="open-dialog" mt:dialog-params="__mode=picapp_find_results&amp;edit_field=<mt:var name="toolbar_edit_field">&amp;blog_id=<mt:var name="blog_id">&amp;from_editor=1" class="command-insert-picapp toolbar button picapp"><b>Insert PicApp Image</b><s></s></a>
END_TMPL
    $$tmpl =~ s{(<b>Insert Image</b><s></s></a>)}{$1$slug2}msg;
}

sub xfrm_asset_options {
    my ($cb, $app, $tmpl) = @_;
    return unless $app->param('is_picapp');
    $$tmpl =~ s{<textarea name="description" id="file_desc" cols="" rows="" class="full-width short"></textarea>}{<textarea name="description" id="file_desc" cols="" rows="" class="full-width short"><mt:var name="description"></textarea>}msg;
    $$tmpl =~ s{File Options}{Image Options}msg;
    $$tmpl =~ s{id="file_name"}{id="file_name" disabled="disabled"}msg;
    $$tmpl =~ s{id="file_desc"}{id="file_desc" disabled="disabled"}msg;
}

sub find_results {
    my $app = shift;

    my $q = $app->{query};
    my $blog = $app->blog;

    my ($keywords,$category,$subcategory);
    if ($q->param('kw')) {
        $keywords    = $q->param('kw');
        $category    = $q->param('category') || 'Editorial';
        $subcategory = $q->param('subcategory') || '';
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

    my $plugin     = MT->component('PicApp');
    my $apikey     = MT->config->PicAppAPIKey;
    my $url        = MT->config->PicAppServerURL;
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
    if (MT->config->DebugMode > 0) {
        MT->log({
            blog_id => $app->blog->id,
            message => "Querying PicApp with the following URL: " . $response->url_queried
                });
    }
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
            thumbnail   => $i->thumbnail_by_size(120),
            caption     => $i->description,
            date        => $i->imageDate
        };
    }

    if ($format eq 'json') {
        return MT::Util::to_json({ 
            images => \@images,
            page_count => int($response->total_records / 20),
            total_results => $response->total_records || 0,
            url_queried => $response->url_queried,
        });
    } else {
        my $tmpl = $app->load_tmpl('dialog/find_results.tmpl');
        $tmpl->param(return_args => "__mode=find&blog_id=".$blog->id."&kw=".$keywords);
        $tmpl->param(total_results => $response->total_records || 0);
        $tmpl->param(page_count => int($response->total_records / 20));
        $tmpl->param(url_queried => $response->url_queried);
        $tmpl->param(blog_id => $blog->id);
        $tmpl->param(blog_name => $blog->name);
        $tmpl->param(images_loop => \@images);
        $tmpl->param(keywords => $keywords);
        $tmpl->param(category => $category);
        $tmpl->param(from_editor  => $q->param('from_editor') );

        return $app->build_page($tmpl);
    }
}

sub asset_options {
    my $app = shift;
    my $q = $app->{query};
    my $blog = $app->blog;
    my $id = $q->param('selected');

    my $plugin     = MT->component('PicApp');
    my $apikey     = MT->config->PicAppAPIKey;
    my $url        = MT->config->PicAppServerURL;
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
        size_large  => 1,
        is_picapp   => 1,
    );
}

1;
