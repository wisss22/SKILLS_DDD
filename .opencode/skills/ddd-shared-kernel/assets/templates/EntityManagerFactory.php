<?php

declare(strict_types=1);

namespace App\<BC>\Shared\Infrastructure\Doctrine;

use App\Shared\Infrastructure\Doctrine\DoctrineEntityManagerFactory;
use Doctrine\ORM\EntityManagerInterface;

use function Lambdish\Phunctional\merge;

/**
 * Factory del EntityManager para el Bounded Context <BC>.
 *
 * Responsabilidades:
 * - Escanear modulos del BC para descubrir entidades Doctrine
 * - Escanear custom DBAL types del BC
 * - Delegar la creacion del EM al factory generico del monorepo Shared
 *
 * Equivalente agnostico:
 * - Spring Boot: @Configuration con @Bean EntityManagerFactory
 *   que usa @EntityScan("<BC>") y @EnableJpaRepositories("<BC>")
 * - NestJS: Custom provider factory para TypeOrmModule
 * - Laravel: ServiceProvider que registra modelos Eloquent del BC
 * - Express/TypeORM: DataSource config con entities: [__dirname + '/../**/*.ts']
 */
final class <BC>EntityManagerFactory
{
	private const string SCHEMA_PATH = __DIR__ . '/../../../../../../etc/databases/<bc>.sql';

	public static function create(array $parameters, string $environment): EntityManagerInterface
	{
		$isDevMode = $environment !== 'prod';

		// Escanear prefijos de mapeo Doctrine de ESTE BC
		// Busca directorios como: src/<BC>/<Module>/Infrastructure/Persistence/Doctrine/
		$prefixes = array_merge(
			DoctrinePrefixesSearcher::inPath(
				__DIR__ . '/../../../../<BC>',
				'App\<BC>'
			),
			// Si este BC necesita leer entidades de otro BC (ej: Backoffice
			// necesita leer cursos de Mooc), agregar aqui. Pero lo ideal es
			// que cada BC sea autonomo en su persistencia.
		);

		// Escanear custom DBAL types de ESTE BC
		// Busca archivos como: src/<BC>/<Module>/Infrastructure/Persistence/Doctrine/*Type.php
		$dbalCustomTypesClasses = DbalTypesSearcher::inPath(
			__DIR__ . '/../../../../<BC>',
			'<BC>'
		);

		// Delegar al factory generico del monorepo Shared
		return DoctrineEntityManagerFactory::create(
			$parameters,
			$prefixes,
			$isDevMode,
			self::SCHEMA_PATH,
			$dbalCustomTypesClasses
		);
	}
}
