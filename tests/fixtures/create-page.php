#!/usr/bin/php
<?php namespace ProcessWire;

if ($argc !== 4) {
    fwrite(STDERR, "usage: create-page.php NAME TITLE BODY\n");
    exit(2);
}

require '/var/www/processwire/index.php';

[$script, $name, $title, $body] = $argv;
if (!preg_match('/^tkl-v19-[a-z0-9-]+$/', $name)) {
    throw new \InvalidArgumentException('invalid test page name');
}

$page = new Page();
$page->template = 'basic-page';
$page->parent = '/';
$page->name = $name;
$page->title = $title;
$page->body = $body;
$page->save();

echo $page->id, "\n";
