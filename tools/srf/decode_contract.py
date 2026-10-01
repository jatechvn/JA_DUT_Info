"""Print resolved SRF DEX instructions; androguard is an external audit tool."""
import argparse
import sys
import zipfile

parser = argparse.ArgumentParser()
parser.add_argument("apk")
parser.add_argument("--package", default="com.qolsys.lucyl10mmi")
parser.add_argument("--class-prefix", default="SRF")
parser.add_argument("--tool-path", help="Isolated androguard installation directory")
args = parser.parse_args()
if args.tool_path:
    sys.path.insert(0, args.tool_path)
from loguru import logger
logger.remove()
from androguard.core.dex import DEX

with zipfile.ZipFile(args.apk) as apk:
    dex = DEX(apk.read("classes.dex"))
for cls in dex.get_classes():
    prefix = "L" + args.package.replace(".", "/") + "/TestItems/" + args.class_prefix
    if not cls.get_name().startswith(prefix):
        continue
    for method in cls.get_methods():
        print("METHOD", cls.get_name(), method.get_name(), method.get_descriptor())
        offset = 0
        for instruction in method.get_instructions():
            print(f"{offset:04x} {instruction.get_name():22} {instruction.get_output()}")
            offset += instruction.get_length()
