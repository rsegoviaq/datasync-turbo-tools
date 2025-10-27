# Paquete de Prueba DataSync s5cmd para Cliente

Paquete de configuración rápida para probar el rendimiento de carga a S3 con s5cmd en conexiones de alto ancho de banda.

## Contenido del Paquete

- **s5cmd**: Herramienta de carga S3 de alto rendimiento (5-12x más rápida que AWS CLI)
- **Scripts de instalación**: Configuración automatizada para Linux/macOS/WSL
- **Herramienta de benchmark**: Comparación de rendimiento entre AWS CLI y s5cmd
- **Ejemplo básico**: Configuración simple de carga

## Inicio Rápido (5 minutos)

### 1. Instalar s5cmd

```bash
chmod +x tools/*.sh scripts/*.sh examples/basic/*.sh
./tools/install-s5cmd.sh
```

### 2. Configurar Credenciales de AWS

```bash
# Opción A: Usar AWS CLI (si ya está configurado)
aws configure

# Opción B: Establecer variables de entorno
export AWS_ACCESS_KEY_ID="tu-access-key"
export AWS_SECRET_ACCESS_KEY="tu-secret-key"
export AWS_DEFAULT_REGION="us-east-1"

# Opción C: Usar Perfil de AWS
export AWS_PROFILE="nombre-de-tu-perfil"
```

### 3. Verificar Instalación

```bash
export S3_BUCKET="nombre-de-tu-bucket-de-prueba"
./tools/verify-installation.sh
```

Salida esperada:
```
✓ s5cmd instalado
✓ Credenciales de AWS válidas
✓ Bucket S3 accesible
```

### 4. Ejecutar Prueba de Benchmark

Prueba el rendimiento de s5cmd vs AWS CLI con 500 MB de datos de prueba:

```bash
export AWS_PROFILE="tu-perfil"  # si usas perfiles
export S3_BUCKET="nombre-de-tu-bucket-de-prueba"

# Ejecutar benchmark (crea 500 MB de datos de prueba)
./tools/benchmark.sh 500
```

**Para pruebas con conexión de 3 Gbps**, prueba con conjuntos de datos más grandes:

```bash
# Prueba de 1 GB
./tools/benchmark.sh 1000

# Prueba de 5 GB (recomendado para 3 Gbps)
./tools/benchmark.sh 5000

# Prueba de 10 GB (para medición de máximo throughput)
./tools/benchmark.sh 10000
```

### 5. Subir Datos Reales (Opcional)

Para probar con tus propios datos:

1. Editar `examples/basic/config.env`:
```bash
export S3_BUCKET="nombre-de-tu-bucket"
export SOURCE_DIR="/ruta/a/tus/datos"
export S3_SUBDIR="prueba-carga"
export AWS_PROFILE="tu-perfil"  # si usas perfiles
```

2. Ejecutar carga:
```bash
cd examples/basic
source config.env
./upload.sh
```

## Rendimiento Esperado

**Tu Conexión: 3 Gbps (~375 MB/s máximo teórico)**

### Expectativas Realistas:
- **AWS CLI**: 40-60 MB/s (10-15% del ancho de banda)
- **s5cmd**: 200-300 MB/s (50-80% del ancho de banda)
- **Mejora**: 5-8x más rápido con s5cmd

### Factores que afectan el rendimiento:
- Tamaño de archivos (más grande = mejor throughput)
- Número de archivos (las cargas paralelas ayudan)
- Latencia de región S3
- Overhead de red (TCP, encriptación)
- Recursos del sistema (CPU, memoria)

## Ejemplo de Salida de Benchmark

```
┌─────────────────────────┬──────────────┬────────────────┬─────────────┐
│ Herramienta             │ Tiempo (s)   │ Throughput     │ Mejora      │
├─────────────────────────┼──────────────┼────────────────┼─────────────┤
│ AWS CLI (default)       │ 69.33        │   7.21 MB/s    │ Baseline    │
│ AWS CLI (optimized)     │ 78.95        │   6.33 MB/s    │ 1.1x        │
│ s5cmd                   │ 58.17        │   8.59 MB/s    │ 1.3x        │
└─────────────────────────┴──────────────┴────────────────┴─────────────┘

🏆 Ganador: s5cmd es 1.3x más rápido que AWS CLI optimizado
```

*(Esta prueba fue en una conexión de 77.73 Mbps - ¡deberías ver resultados mucho mejores con 3 Gbps!)*

## Solución de Problemas

### s5cmd no encontrado
```bash
# Verificar PATH
echo $PATH

# Instalar manualmente
./tools/install-s5cmd.sh
```

### Error de credenciales de AWS
```bash
# Verificar credenciales
aws sts get-caller-identity

# O con perfil
aws --profile tu-perfil sts get-caller-identity
```

### Acceso denegado al bucket S3
```bash
# Probar acceso al bucket
aws s3 ls s3://nombre-de-tu-bucket/

# Verificar que el bucket existe y tienes permisos
```

### Rendimiento lento
- Usa tamaños de prueba más grandes (5-10 GB) para ver mejor throughput
- Asegúrate de no estar en VPN
- Verifica que la región del bucket S3 coincida con tu ubicación
- Verifica que no haya throttling de ancho de banda en la red

## Recomendaciones de Prueba para 3 Gbps

1. **Empezar pequeño**: Ejecuta prueba de 500 MB para verificar que todo funciona
2. **Escalar**: Ejecuta prueba de 5 GB para ver rendimiento real
3. **Dataset grande**: Ejecuta prueba de 10 GB para medición de máximo throughput
4. **Anotar resultados**: Guarda la salida del benchmark para compartir con nosotros

## ¿Necesitas Ayuda?

- Consulta `examples/basic/README.md` para opciones detalladas de configuración
- Revisa el archivo de resultados de benchmark: `benchmark-results-*.txt`
- Contacta a soporte con los resultados del benchmark y cualquier error

## Limpiar Datos de Prueba

El benchmark limpia automáticamente los archivos temporales y objetos de prueba en S3.

Para limpiar manualmente los datos de prueba en S3:
```bash
# Usando s5cmd
s5cmd rm "s3://tu-bucket/benchmark-test-*/*"

# Usando AWS CLI
aws s3 rm s3://tu-bucket/benchmark-test- --recursive
```

## Contenido del Paquete

```
datasync-client-package/
├── README.md                          # Documentación en inglés
├── README.es.md                       # Documentación en español (este archivo)
├── tools/
│   ├── install-s5cmd.sh              # Instalar s5cmd
│   ├── verify-installation.sh        # Verificar configuración
│   └── benchmark.sh                  # Pruebas de rendimiento
├── scripts/
│   └── datasync-s5cmd.sh            # Script principal de carga
└── examples/basic/
    ├── README.md                     # Guía detallada
    ├── config.env                    # Plantilla de configuración
    └── upload.sh                     # Wrapper simple de carga
```

## Notas Importantes

- El benchmark crea archivos de prueba temporales que se eliminan automáticamente
- Los datos de prueba cargados a S3 se limpian automáticamente después del benchmark
- Para pruebas con datos reales, usa el ejemplo básico en `examples/basic/`
- Guarda los resultados del benchmark para referencia futura

## Comandos Rápidos de Referencia

```bash
# Instalar
./tools/install-s5cmd.sh

# Verificar
export S3_BUCKET="tu-bucket"
./tools/verify-installation.sh

# Benchmark pequeño (500 MB)
export AWS_PROFILE="tu-perfil"
export S3_BUCKET="tu-bucket"
./tools/benchmark.sh 500

# Benchmark grande (5 GB) - Recomendado para 3 Gbps
./tools/benchmark.sh 5000

# Carga de datos reales
cd examples/basic
source config.env  # Editar primero con tus valores
./upload.sh
```

## Resultados Esperados en tu Conexión

Con tu conexión de **3 Gbps** (~375 MB/s teórico):

- **Prueba de 500 MB**: Completar en ~2-3 segundos con s5cmd
- **Prueba de 5 GB**: Completar en ~20-25 segundos con s5cmd
- **Prueba de 10 GB**: Completar en ~40-50 segundos con s5cmd

**Throughput esperado con s5cmd**: 200-300 MB/s (50-80% del ancho de banda)

---

**Versión**: 1.0.0
**Fecha de Prueba**: Octubre 2025
**Rendimiento Verificado**: Hasta 8.59 MB/s en conexión de 77 Mbps (88% de utilización de ancho de banda)
