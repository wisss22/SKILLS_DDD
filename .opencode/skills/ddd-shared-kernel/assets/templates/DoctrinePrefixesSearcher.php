<?php

declare(strict_types=1);

namespace App\<BC>\Shared\Infrastructure\Doctrine;

/**
 * Escaner de prefijos de mapeo Doctrine para el Bounded Context <BC>.
 *
 * Responsabilidad:
 * - Recorrer todos los modulos del BC
 * - Encontrar directorios de mapeo Doctrine (XML/YAML)
 * - Retornar un mapa [ruta => namespace] para el EntityManager
 *
 * Ejemplo de salida:
 * [
 *   '/src/<BC>/Courses/Infrastructure/Persistence/Doctrine' => 'App\<BC>\Courses\Domain',
 *   '/src/<BC>/Videos/Infrastructure/Persistence/Doctrine'  => 'App\<BC>\Videos\Domain',
 * ]
 *
 * Equivalente agnostico:
 * - Spring Boot: @EntityScan con basePackages
 * - NestJS/TypeORM: entities: [__dirname + '/../**/*.entity.ts']
 * - Laravel: DatabaseServiceProvider que carga models de modulos
 */
final class DoctrinePrefixesSearcher
{
	/**
	 * @return array<string, string> [ruta => namespace]
	 */
	public static function inPath(string $path, string $baseNamespace): array
	{
		$prefixes = [];

		// Itera sobre cada modulo en el path del BC: src/<BC>/<Module>/
		foreach (glob($path . '/*', GLOB_ONLYDIR) as $moduleDir) {
			$module = basename($moduleDir);

			// Busca la carpeta de mapeo Doctrine
			$possibleMappingDir = $moduleDir . '/Infrastructure/Persistence/Doctrine';

			if (is_dir($possibleMappingDir)) {
				$prefixes[$possibleMappingDir] = $baseNamespace . '\\' . $module . '\\Domain';
			}
		}

		return $prefixes;
	}
}
