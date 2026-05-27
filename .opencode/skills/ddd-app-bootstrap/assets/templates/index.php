<?php

declare(strict_types=1);

use App\Apps\<BC>\Backend\<BC>BackendKernel;
use Symfony\Component\ErrorHandler\Debug;
use Symfony\Component\HttpFoundation\Request;

/**
 * Punto de entrada HTTP (Front Controller) para el Bounded Context <BC>.
 *
 * Responsabilidades:
 * - Arrancar el entorno (autoloader, variables de entorno)
 * - Instanciar el Kernel del BC
 * - Transformar la peticion HTTP en una Response
 *
 * Equivalentes en otros frameworks:
 * - Laravel: public/index.php
 * - Spring Boot: ServletInitializer o @SpringBootApplication main()
 * - NestJS: bootstrap() en main.ts que crea NestApplication
 * - Express: app.listen() en server.js
 */

require dirname(__DIR__) . '/../../bootstrap.php';

if ($_SERVER['APP_DEBUG']) {
	umask(0000);

	Debug::enable();
}

if ($trustedProxies = $_SERVER['TRUSTED_PROXIES'] ?? $_ENV['TRUSTED_PROXIES'] ?? false) {
	Request::setTrustedProxies(
		explode(',', $trustedProxies),
		Request::HEADER_X_FORWARDED_FOR | Request::HEADER_X_FORWARDED_PORT | Request::HEADER_X_FORWARDED_PROTO
	);
}

if ($trustedHosts = $_SERVER['TRUSTED_HOSTS'] ?? $_ENV['TRUSTED_HOSTS'] ?? false) {
	Request::setTrustedHosts([$trustedHosts]);
}

$kernel = new <BC>BackendKernel($_SERVER['APP_ENV'], (bool) $_SERVER['APP_DEBUG']);
$request = Request::createFromGlobals();
$response = $kernel->handle($request);
$response->send();
$kernel->terminate($request, $response);
