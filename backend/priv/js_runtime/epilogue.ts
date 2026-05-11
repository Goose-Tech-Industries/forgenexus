// --- ForgeNexus Plugin Epilogue ---
// This is appended after the plugin code to serialize the output.

console.log(JSON.stringify({ output: _output, logs: _logs, commands: _commands }));
