<?php
namespace k1\Blocks;

function Typer() {
  $text = get_field('typer');

  if (empty($text)) {
    $text = 'Add some text';
  }

  echo "<div class='k1-block k1-typer-text'>$text</div>";
}
