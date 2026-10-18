import subprocess
import sys
from pathlib import Path

target = Path(__file__).resolve().parent.parent.parent / "tests" / "test_p14_m4_challenger2_stress.py"
sys.exit(subprocess.call([sys.executable, str(target)] + sys.argv[1:]))
