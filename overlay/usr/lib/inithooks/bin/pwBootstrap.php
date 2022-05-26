#!/usr/bin/php
<?php namespace ProcessWire;
include("/var/www/processwire/index.php"); // bootstrap ProcessWire

$admin = $users->get('admin');
$admin->setOutputFormatting(false);
$admin->pass = $_SERVER['argv'][1];
$admin->email = $_SERVER['argv'][2];
$admin->save();
?>
