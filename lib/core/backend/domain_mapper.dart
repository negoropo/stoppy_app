abstract class DomainMapper<Domain, Dto> {
  const DomainMapper();

  Dto toDto(Domain domain);

  Domain toDomain(Dto dto);
}
