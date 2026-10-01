import 'dart:io';

void main(List<String> args) {
  stdout.writeln('READY:25390A');
  if (stdin.readLineSync() != 'GO') exit(1);
  stdout.writeln('ARMED:25390A');
  stdout.writeln(args.single);
}
