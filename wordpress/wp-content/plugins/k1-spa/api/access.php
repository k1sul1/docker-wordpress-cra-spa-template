<?php
namespace k1\Routes;

class Access extends \k1\RestRoute {
  public function __construct() {
    parent::__construct('k1/v1', 'access');

    $this->registerEndpoint(
      '/has',
      [
        'methods' => 'POST',
        'callback' => [$this, 'hasAccess'],
      ]
    );

    $this->registerEndpoint(
      '/plz',
      [
        'methods' => 'GET',
        'callback' => [$this, 'iCanHaz'],
      ]
    );
  }

  /**
   * Check that the cookie is valid.
   * Used by sites to verify if the credentials are correct.
   */
  public function hasAccess(\WP_REST_Request $request) {

  }

  /**
   * Check if the provided "credentials" are valid. If they are,
   * the service that made the request should set a cookie to the location.
   */
  public function iCanHaz(\WP_REST_Request $request) {
    $posts = get_posts([
      'numberposts' => 100, // If I ever have more than 100 sites using the same password... punch me
      'meta_key' => 'staging_domain',
      'post_type' => 'staging',
    ]);

    global $wp_rest_server;
    $req = new \WP_REST_Request("GET", "/wp/v2/staging/{$id}");
    $req = apply_filters('k1_resolver_resolve_request', $req, $request);

    $response = rest_do_request($req);

    $data = $wp_rest_server->response_to_data($response, true);
    $response->set_data($data);
    $response = apply_filters('k1_resolver_resolve_response', $response, $request);

    return $response;

    return new \WP_REST_Response([
      'lol' => $posts,
    ]);
  }
}
