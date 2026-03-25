/**
 * Represents ZAR AWS environments
 */
export enum ENVIRONMENT {
  DEVELOPMENT = 'development',
  PRODUCTION = 'production',
  STAGING = 'staging',
}

/**
 * Current environment based on ENVIRONMENT env var
 * Defaults to 'development' if not set.
 */
export const environment = (process.env.ENVIRONMENT as ENVIRONMENT) || ENVIRONMENT.DEVELOPMENT;

/**
 * AWS primary region (UAE)
 */
export const region = 'eu-central-1';

/**
 * Application name
 */
export const appName = 'fizzy';

/**
 * VPC name where ZAR applications are provisioned
 */
export const vpcName = 'ZarVpc';

/**
 * Shared Application Load Balancer
 */
export const albName = 'ZarSharedALB';

/**
 * Shared ECS cluster
 */
export const clusterName = 'ZarECSCluster';

/**
 * SMTP configuration (SES in Frankfurt)
 * Credentials stored in Secrets Manager: /platform/smtp/credentials
 */
export const smtp = {
  address: 'email-smtp.eu-central-1.amazonaws.com',
  fromAddress: 'fizzy@zarpay.app',
  port: 587,
};

/**
 * Whether this is a production environment
 */
export const isProduction = environment === ENVIRONMENT.PRODUCTION;
