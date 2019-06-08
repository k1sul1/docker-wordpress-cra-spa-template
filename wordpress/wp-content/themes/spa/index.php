<?php
global $wp;

$react = str_replace("://wp.", "://", home_url($wp->request));
header("Location: $react");
die();
