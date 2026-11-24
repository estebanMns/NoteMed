/// Versión de las instrucciones (prompts) que la app envía a la IA. Los
/// prompts se versionan como código (MLOps): se sube esta versión cada vez
/// que cambia el texto de alguno, y se guarda en cada nota para saber con
/// qué versión se generó.
library;

const String versionPrompts = '1.1.0';
