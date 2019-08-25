requires 'Dist::Zilla', '4.300034';
requires 'YAML', '1.14';
requires 'Beam::Event', '0';

on test => sub {
  requires 'Dist::Zilla::Plugin::Beam::Connector', '0';
  requires 'Path::Tiny', '0';
  requires 'Test::DZil', '0';
  requires 'Test::More', '0';
};
