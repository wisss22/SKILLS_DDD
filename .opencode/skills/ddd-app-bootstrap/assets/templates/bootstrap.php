<?php

declare(strict_types=1);

use Symfony\Component\Dotenv\Dotenv;

/**
 * Bootstrap compartido para todas las apps del monorepo.
 *
 * Responsabilidades:
 * - Cargar el autoloader de Composer
 * - Cargar variables de entorno desde .env
 * - Establecer APP_ENV y APP_DEBUG con valores por defecto
 *
 * Este archivo es requerido por:
 * - apps/<bc>/backend/public/index.php (entrypoint HTTP)
 * - apps/<bc>/backend/bin/console     (entrypoint CLI)
 *
 * Equivalentes en otros frameworks:
 * - Laravel: bootstrap/app.php
 * - Spring Boot: carga de application.properties via Environment
 * - NestJS: dotenv.config() al inicio de main.ts
 * - Express: require('dotenv').config() en server.js
 */

$rootPath = dirname(__DIR__);

require $rootPath . '/vendor/autoload.php';

(new Dotenv())->loadEnv($rootPath . '/.env');

$_SERVER += $_ENV;
$_SERVER['APP_ENV'] = $_ENV['APP_ENV'] = ($_SERVER['APP_ENV'] ?? $_ENV['APP_ENV'] ?? null) ?: 'dev';
$_SERVER['APP_DEBUG'] ??= $_ENV['APP_DEBUG'] ?? $_SERVER['APP_ENV'] !== 'prod';
$_SERVER['APP_DEBUG'] = $_ENV['APP_DEBUG'] =
	(int) $_SERVER['APP_DEBUG'] || filter_var($_SERVER['APP_DEBUG'], FILTER_VALIDATE_BOOLEAN) ? '1' : '0';
