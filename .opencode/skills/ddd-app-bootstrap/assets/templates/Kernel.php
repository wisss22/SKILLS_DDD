<?php

declare(strict_types=1);

namespace App\Apps\<BC>\Backend;

use Symfony\Bundle\FrameworkBundle\Kernel\MicroKernelTrait;
use Symfony\Component\Config\Loader\LoaderInterface;
use Symfony\Component\Config\Resource\FileResource;
use Symfony\Component\DependencyInjection\ContainerBuilder;
use Symfony\Component\HttpKernel\Kernel;

use function dirname;

/**
 * Application Bootstrapper del Bounded Context <BC>.
 *
 * Responsabilidades:
 * - Cargar modulos/framework (bundles)
 * - Configurar el contenedor DI desde config/services*.yaml
 * - Establecer el directorio raiz de la app
 *
 * En otros frameworks este concepto se conoce como:
 * - Laravel: Service Container bootstrap en AppServiceProvider
 * - Spring Boot: Clase anotada con @SpringBootApplication
 * - NestJS: AppModule con @Module()
 * - Express: app.js con middlewares y routers
 */
class <BC>BackendKernel extends Kernel
{
	use MicroKernelTrait;

	private const string CONFIG_EXTS = '.{xml,yaml}';

	/**
	 * Registra los modulos/framework activos segun el entorno.
	 * Equivalente a:
	 * - Laravel: providers en config/app.php
	 * - Spring Boot: @Import o @ComponentScan
	 * - NestJS: imports dentro de @Module()
	 */
	public function registerBundles(): iterable
	{
		$contents = require $this->getProjectDir() . '/config/bundles.php';
		foreach ($contents as $class => $envs) {
			if ($envs[$this->environment] ?? $envs['all'] ?? false) {
				yield new $class();
			}
		}
	}

	/**
	 * Define el directorio raiz de esta app.
	 */
	public function getProjectDir(): string
	{
		return dirname(__DIR__);
	}

	/**
	 * Carga la configuracion del contenedor DI.
	 * Busca todos los archivos services*.yaml en config/.
	 */
	protected function configureContainer(ContainerBuilder $container, LoaderInterface $loader): void
	{
		$container->addResource(new FileResource($this->getProjectDir() . '/config/bundles.php'));
		$container->setParameter('.container.dumper.inline_class_loader', true);
		$confDir = $this->getProjectDir() . '/config';

		$loader->load($confDir . '/services' . self::CONFIG_EXTS, 'glob');
		$loader->load($confDir . '/services_' . $this->environment . self::CONFIG_EXTS, 'glob');
		$loader->load($confDir . '/services/*' . self::CONFIG_EXTS, 'glob');
	}
}
