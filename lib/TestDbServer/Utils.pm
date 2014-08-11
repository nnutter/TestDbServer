package TestDbServer::Utils;

sub id_url_for_request_and_entity_id {
    my($req, $id) = @_;

    my $base_url = join('', $req->url->base, $req->url->path);
    return join('/', $base_url, $id);
}

1;
