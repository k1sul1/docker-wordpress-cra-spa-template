<?php
/**
 * Plugin name: k1 spa
 * Description: Whatever is necessary to bend WordPress to my will
 */

namespace k1;

if (!defined("ABSPATH")) {
  die("You're not supposed to be here.");
}

add_action('plugins_loaded', function() {
  add_action('after_setup_theme', function() {
    add_theme_support('post-thumbnails');
    add_theme_support('html5');
    add_theme_support('responsive-embeds');
  });

  add_action('admin_head', function() {
    ?>
    <style>
      .k1-block {
        /* border: 2px solid #222; */
        /* min-height: 50px; */
        /* display: inline-block; */
      }
    </style>
    <?php
  });

  add_filter('acf/settings/save_json', function($path) {
    return __DIR__ . '/acf-json';
  });

  add_action('acf/init', function() {
    if (function_exists('acf_register_block')) {
      $blocks = [
        'Scrambler' => [
          'description' => 'Will scramble provided text. Do not fucking overuse.',
          'category' => 'formatting',
        ],
        'Typer' => [
          'description' => 'Typewriter effect',
          'category' => 'formatting',
        ],
      ];

      foreach ($blocks as $name => $block) {
        $block = array_merge([
          // defaults that can be overwritten
          'title' => $name,
          'name' => strtolower($name),
          'render_callback' => "\\k1\\Blocks\\$name",
          'mode' => 'auto',
          'supports' => [
            'align' => false,
          ],
        ], $block);

        require_once("blocks/$name.php");
        acf_register_block($block);
      }
    }
  });

  add_action('rest_api_init', function() {
    /**
     * Get all REST enabled post types
     */
    $postTypes = array_filter(
      get_post_types([], 'objects'),
      function($type) {
        return $type->show_in_rest === true;
      }
    );

    foreach ($postTypes as $type) {
      register_rest_field($type->name, 'acf', [
        'get_callback' => '\k1\getAllowedCustomFields',
      ]);

      register_rest_field($type->name, 'blocks', [
        'get_callback' => '\k1\getBlockData',
      ]);
    }
  });

  function getAllowedCustomFields($post) {
    $fields = get_fields($post['id']);

    /**
     * If you're feeling fancy, check user authentication here and allow more fields
     */
    $removeFields = function($field) use (&$removeFields) {
      return true;
    };

    return array_filter($fields, $removeFields);
  }

  function getBlockData($post) {
    return has_blocks($post['content']['raw']) ? parse_blocks($post['content']['raw']) : false;
  }
});

