<?php
namespace k1\Blocks;

function Scrambler() {
  $text = get_field('text');

  if (!$text) {
    $text = 'Add text to be scrambled';
  }

  echo "<span class='k1-block k1-scrambled-text'>$text</span>";
}
