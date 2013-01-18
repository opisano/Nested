import os
import os.path

# Creates a test suite program that will execute every unit test.
env = Environment(LINKFLAGS= '-m32', \
	DFLAGS = ['-gc', '-debug', '-w'], \
	ENV=os.environ)

sources = ['cpu.d', 'ppu.d', 'memory.d', 'main.d', 'file/rom.d', 'file/ines.d', 
'controller.d', 'audio/lengthcounter.d', 'audio/noise.d']

env.Program('nested', sources)

