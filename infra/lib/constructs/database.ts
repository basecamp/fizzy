import { Construct } from 'constructs';
import * as cdk from 'aws-cdk-lib';
import * as logs from 'aws-cdk-lib/aws-logs';
import * as rds from 'aws-cdk-lib/aws-rds';
import * as ec2 from 'aws-cdk-lib/aws-ec2';
import * as secrets from 'aws-cdk-lib/aws-secretsmanager';
import { config } from '../../environments/config-loader';
import { environment, isProduction } from '../shared/global-variables';

export interface DatabaseProps {
  vpc: ec2.IVpc;
}

export class Database extends Construct {
  public readonly dbSecret: secrets.ISecret;
  public readonly cluster: rds.DatabaseCluster;

  constructor(scope: Construct, id: string, props: DatabaseProps) {
    super(scope, id);

    this.dbSecret = this.createDbSecret();
    this.cluster = this.createDatabaseCluster(props.vpc);
  }

  private createDbSecret() {
    return new secrets.Secret(this, 'FizzyDbPassword', {
      secretName: `/fizzy/${environment}/db-password`,
      description: 'Fizzy Database Password',
      generateSecretString: {
        excludePunctuation: true,
        excludeCharacters: '"@/\\%!:;,.&$#*{}[]`~',
        generateStringKey: 'password',
        secretStringTemplate: '{"username": "fizzy"}',
      },
      removalPolicy: isProduction ? cdk.RemovalPolicy.RETAIN : cdk.RemovalPolicy.DESTROY,
    });
  }

  private createDatabaseCluster(vpc: ec2.IVpc) {
    const sg = this.createSecurityGroup(vpc);

    const subnetGroup = new rds.SubnetGroup(this, 'FizzyDbSubnetGroup', {
      description: 'Subnet group for Fizzy Aurora MySQL cluster',
      subnetGroupName: `fizzy-${environment}-subnet-group`,
      vpc,
      vpcSubnets: { subnets: vpc.isolatedSubnets },
      removalPolicy: isProduction ? cdk.RemovalPolicy.RETAIN : cdk.RemovalPolicy.DESTROY,
    });

    return new rds.DatabaseCluster(this, 'FizzyAuroraCluster', {
      clusterIdentifier: `fizzy-${environment}`,
      engine: rds.DatabaseClusterEngine.auroraMysql({
        version: rds.AuroraMysqlEngineVersion.VER_3_08_0,
      }),
      credentials: rds.Credentials.fromSecret(this.dbSecret),
      defaultDatabaseName: 'fizzy',
      vpc,
      subnetGroup,
      securityGroups: [sg],
      serverlessV2MinCapacity: config.database?.minCapacity ?? 0,
      serverlessV2MaxCapacity: config.database?.maxCapacity ?? 2,
      writer: rds.ClusterInstance.serverlessV2('writer', {
        instanceIdentifier: `fizzy-${environment}-writer`,
      }),
      readers: [
        rds.ClusterInstance.serverlessV2('reader', {
          instanceIdentifier: `fizzy-${environment}-reader`,
        }),
      ],
      backup: {
        retention: cdk.Duration.days(7),
        preferredWindow: '03:00-04:00',
      },
      preferredMaintenanceWindow: 'sun:04:00-sun:05:00',
      deletionProtection: false,
      storageEncrypted: true,
      monitoringInterval: cdk.Duration.seconds(60),
      cloudwatchLogsExports: ['error', 'slowquery'],
      cloudwatchLogsRetention: logs.RetentionDays.ONE_WEEK,
      removalPolicy: isProduction ? cdk.RemovalPolicy.RETAIN : cdk.RemovalPolicy.DESTROY,
    });
  }

  private createSecurityGroup(vpc: ec2.IVpc) {
    const sg = new ec2.SecurityGroup(this, 'FizzyAuroraSg', {
      vpc,
      description: 'Allow access to Fizzy Aurora MySQL cluster',
      allowAllOutbound: false,
    });

    sg.addIngressRule(ec2.Peer.ipv4(vpc.vpcCidrBlock), ec2.Port.tcp(3306), 'Allow MySQL access from VPC');

    return sg;
  }
}
