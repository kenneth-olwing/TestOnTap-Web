use FindBin;
die($@ || $!) unless do "$FindBin::Bin/common.plinc";
TestOnTap::Web::App->dance();
